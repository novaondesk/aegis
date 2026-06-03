// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Minimal Ownable (OZ-compatible surface) — shim for the vendored Dex level.
contract Ownable {
    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }
}
