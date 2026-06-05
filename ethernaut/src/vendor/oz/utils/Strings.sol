// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// Minimal OZ-compatible Strings shim for the Ethernaut wargame harness.
/// Provides `toString(uint256)` used by ImpersonatorTwo.
library Strings {
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}