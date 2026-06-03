// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.7.0;

// Minimal OZ-0.6 Initializable shim (the `initializer` once-guard) for the vendored Motorbike level.
contract Initializable {
    bool private _initialized;
    bool private _initializing;

    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: already initialized");
        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}
