// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;

// Minimal OZ-0.6 Address shim (isContract) for the vendored Motorbike level.
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
