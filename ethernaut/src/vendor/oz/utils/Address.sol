// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Minimal OZ-0.8 Address shim (isContract) for the vendored GoodSamaritan level.
library Address {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}
