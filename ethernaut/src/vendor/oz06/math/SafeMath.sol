// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;

// Minimal OZ-0.6 SafeMath shim (add) for the vendored Reentrance level.
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
}
