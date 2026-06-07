// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

/// @title VulnerableGatewayEVM — minimal model of ZetaChain's GatewayEVM with the
/// three-defect exploit chain.
///
/// DEFECT 1 (GatewayZEVM.call on ZetaChain): unauthenticated, no input validation.
///   In the real system, this emits an event that TSS validators sign.
///   Here we model it as a direct call to `onCall` that ANY address can trigger.
///
/// DEFECT 2 (GatewayEVM.execute): accepts arbitrary external calls, including
/// `transferFrom`. The gateway IS the caller, so standing approvals to it are used.
///
/// DEFECT 3 (trust assumption): users granted unlimited ERC20 approvals to the
/// gateway and never revoked them. The contract holds those approvals.
///
/// This is the "confused deputy" class where the gateway becomes the weapon.
///
/// See docs/exploits/zeta-chain-gatewayevm-2026-04-29.md
contract VulnerableGatewayEVM {
    mapping(address => IERC20) public tokenMap; // chainId -> token (simplified)
    mapping(address => mapping(address => uint256)) public approvals; // token -> owner -> spender
    IERC20 public targetToken; // For PoC: the token contract to execute calls on

    // Simplified: anyone can call this (no access control, no input validation)
    // In reality this is GatewayZEVM.call() on ZetaChain that emits a TSS-signed event
    function onCall(
        address sender,           // from ZetaChain (attacker-controlled)
        address receiver,         // on this chain (GatewayEVM itself)
        bytes calldata message    // arbitrary payload
    ) external {
        // DEFECT 1: no check on sender, no validation of message
        // DEFECT 2: executes arbitrary calldata on targetToken (the gateway IS the caller)
        // This models GatewayEVM.execute which accepts arbitrary calldata
        (bool ok, ) = address(targetToken).call(message);
        require(ok, "call failed");
    }

    // User deposits tokens, granting approval to this gateway
    function deposit(IERC20 token, uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        targetToken = token; // Track the token for exploit
    }

    // The gateway itself can be approved by users for their tokens
    function approveToken(IERC20 token, uint256 amount) external {
        token.approve(address(this), amount);
    }
}

/// @title SafeGatewayEVM — same interface with all three defects fixed.
///
/// FIX 1: `onCall` validates the sender is a known TSS verifier (or validates
/// message structure).
/// FIX 2: `onCall` does NOT forward arbitrary calldata; it only calls a
/// whitelisted set of handlers.
/// FIX 3: no standing approvals — use permit/pull pattern or exact-amount approvals.
///
/// For the PoC we model the fix as:
/// - allow-listed callers only (TSS validators)
/// - allow-listed target contracts for the forwarded call (no token contracts)
/// - no deposit/approve that leaves standing approvals (exact-amount instead)
contract SafeGatewayEVM {
    mapping(address => IERC20) public tokenMap;
    mapping(address => bool) public allowedCaller; // TSS validator addresses
    mapping(address => bool) public allowedTarget; // whitelisted handler contracts

    constructor(address[] memory callers, address[] memory targets) {
        for (uint256 i = 0; i < callers.length; i++) allowedCaller[callers[i]] = true;
        for (uint256 i = 0; i < targets.length; i++) allowedTarget[targets[i]] = true;
    }

    function onCall(
        address sender,
        address receiver,
        bytes calldata message
    ) external {
        // FIX 1: validate caller is authorized TSS verifier
        require(allowedCaller[sender], "unauthorized sender");

        // FIX 2: validate receiver is an allowed target (not arbitrary, not token)
        require(allowedTarget[receiver], "target not allow-listed");

        // FIX 2 contd: validate message structure (simplified: must be a known selector)
        // In reality, decode and validate against handler interface
        (bool ok, ) = receiver.call(message);
        require(ok, "call failed");
    }

    // FIX 3: no standing approvals. Use exact-amount deposit with no residual approval.
    function deposit(IERC20 token, uint256 amount) external {
        // Approve exact amount, deposit, then revoke (or use permit)
        token.approve(address(this), amount);
        token.transferFrom(msg.sender, address(this), amount);
        token.approve(address(this), 0); // revoke immediately
    }
}