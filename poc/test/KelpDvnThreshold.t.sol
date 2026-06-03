// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20, VulnerableDvnBridge, SafeDvnBridge, DvnBridgeBase} from "../src/attestation/DvnBridge.sol";

/// PoC for insufficient attestation threshold — the Kelp DAO / LayerZero 1-of-1 DVN class (~$292M).
///   forge test --match-contract KelpDvnThreshold -vvv
///
/// Invariant (X01): a cross-chain release must require attestations from >= 2 independent
/// verifiers, so no single compromised verifier can authorize a fraudulent transfer. The 1-of-1
/// bridge releases on one signature; requiring >= 2 distinct verifiers holds.
///
/// See docs/exploits/kelp-dao-layerzero-dvn-2026-04-18.md
contract KelpDvnThresholdTest is Test {
    MockERC20 token;
    address attacker = makeAddr("attacker");

    // verifier set
    address v1;
    uint256 v1pk;
    address v2;
    uint256 v2pk;

    function setUp() public {
        token = new MockERC20();
        (v1, v1pk) = makeAddrAndKey("verifier1");
        (v2, v2pk) = makeAddrAndKey("verifier2");
    }

    function _sign(uint256 pk, address bridge, address to, uint256 amount, uint256 nonce)
        internal
        pure
        returns (DvnBridgeBase.Sig memory)
    {
        bytes32 h = keccak256(abi.encodePacked(bridge, to, amount, nonce));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", h));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        return DvnBridgeBase.Sig(v, r, s);
    }

    function test_vulnerable_singleCompromisedVerifierDrains() public {
        // 1-of-1 DVN: the only verifier is v1, whose key the attacker has compromised.
        address[] memory verifiers = new address[](1);
        verifiers[0] = v1;
        VulnerableDvnBridge bridge = new VulnerableDvnBridge(IERC20(address(token)), verifiers);
        token.mint(address(bridge), 292e18);

        // One forged attestation from the single compromised verifier authorizes the release.
        DvnBridgeBase.Sig[] memory sigs = new DvnBridgeBase.Sig[](1);
        sigs[0] = _sign(v1pk, address(bridge), attacker, 292e18, 0);

        bridge.release(attacker, 292e18, 0, sigs);

        assertEq(token.balanceOf(attacker), 292e18, "single verifier authorized the full drain");
        assertEq(token.balanceOf(address(bridge)), 0, "bridge reserve emptied");
    }

    function test_safe_requiresTwoIndependentVerifiers() public {
        // 2-of-2: verifier set {v1, v2}; the attacker has compromised only v1.
        address[] memory verifiers = new address[](2);
        verifiers[0] = v1;
        verifiers[1] = v2;
        SafeDvnBridge bridge = new SafeDvnBridge(IERC20(address(token)), verifiers);
        token.mint(address(bridge), 292e18);

        // One compromised verifier is no longer enough.
        DvnBridgeBase.Sig[] memory one = new DvnBridgeBase.Sig[](1);
        one[0] = _sign(v1pk, address(bridge), attacker, 292e18, 0);
        vm.expectRevert(bytes("insufficient attestations"));
        bridge.release(attacker, 292e18, 0, one);

        assertEq(token.balanceOf(address(bridge)), 292e18, "reserve untouched by a single forgery");

        // Legitimate release: two distinct verifiers attest (sigs sorted by signer address).
        DvnBridgeBase.Sig memory s1 = _sign(v1pk, address(bridge), attacker, 10e18, 1);
        DvnBridgeBase.Sig memory s2 = _sign(v2pk, address(bridge), attacker, 10e18, 1);
        DvnBridgeBase.Sig[] memory two = new DvnBridgeBase.Sig[](2);
        (two[0], two[1]) = v1 < v2 ? (s1, s2) : (s2, s1);

        bridge.release(attacker, 10e18, 1, two);
        assertEq(token.balanceOf(attacker), 10e18, "two-of-two attestation releases legitimately");
    }
}
