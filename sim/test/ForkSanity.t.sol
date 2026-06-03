// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

/// Harness shake-out: proves we can fork Ethereum at a pinned historical block, read REAL on-chain
/// state of a live contract, and fund an attacker with real tokens via cheatcodes. If this passes,
/// the fork-simulation pipeline works and incident replays can build on it.
///   set -a; source .env; set +a; forge test --match-contract ForkSanity -vvv
contract ForkSanityTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 constant PIN_BLOCK = 21_000_000; // Nov 2024

    function test_forkReadsRealMainnetState() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), PIN_BLOCK);

        assertEq(block.chainid, 1, "forked Ethereum mainnet");
        assertEq(block.number, PIN_BLOCK, "pinned to the requested block");

        // Read the REAL deployed USDC contract's state at this block.
        uint256 supply = IERC20(USDC).totalSupply();
        emit log_named_uint("real USDC totalSupply @ block", supply);
        assertGt(supply, 1_000_000_000e6, "USDC supply is billions - real state, not a blank chain");

        // Fund an attacker with real USDC via a cheatcode (no need to source it on-chain).
        address attacker = makeAddr("attacker");
        deal(USDC, attacker, 1_000e6);
        assertEq(IERC20(USDC).balanceOf(attacker), 1_000e6, "attacker funded with real-token balance");
    }
}
