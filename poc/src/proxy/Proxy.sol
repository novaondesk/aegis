// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Proxy storage-slot collision: a delegatecall proxy keeps its own admin in a *sequential*
/// storage slot (slot 0), and the implementation it delegatecalls into declares a state var in
/// that same slot 0. Because delegatecall executes against the PROXY's storage, any logic
/// function that writes its slot-0 var silently overwrites the proxy admin — letting an attacker
/// seize upgrade rights. This is the Audius-class (2022) upgradeable-proxy collision bug.
///
/// See docs/exploits/proxy-storage-collision-2022-07.md

/// Shared implementation logic. `owner` lives at slot 0 — the collision surface.
contract Logic {
    address public owner;  // slot 0
    uint256 public value;  // slot 1

    function initialize(address o) external {
        owner = o;
    }

    function setValue(uint256 v) external {
        require(msg.sender == owner, "not owner");
        value = v;
    }
}

/// VULNERABLE: admin sits in sequential slot 0 — the SAME slot Logic uses for `owner`. A call to
/// Logic.initialize() routed through the proxy delegatecalls into Logic and writes slot 0 of the
/// PROXY, overwriting `admin`.
contract VulnerableProxy {
    address public admin;          // slot 0  <-- collides with Logic.owner
    address public implementation; // slot 1  <-- collides with Logic.value

    constructor(address impl) {
        admin = msg.sender;
        implementation = impl;
    }

    function upgrade(address newImpl) external {
        require(msg.sender == admin, "not admin");
        implementation = newImpl;
    }

    fallback() external payable {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

/// SAFE: admin and implementation live in EIP-1967 unstructured slots (keccak-derived, not
/// sequential), so no implementation state var can ever collide with them.
contract SafeProxy {
    // bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
    bytes32 internal constant ADMIN_SLOT =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    // bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 internal constant IMPL_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address impl) {
        _set(ADMIN_SLOT, msg.sender);
        _set(IMPL_SLOT, impl);
    }

    function admin() external view returns (address) {
        return _get(ADMIN_SLOT);
    }

    function upgrade(address newImpl) external {
        require(msg.sender == _get(ADMIN_SLOT), "not admin");
        _set(IMPL_SLOT, newImpl);
    }

    function _set(bytes32 slot, address a) internal {
        assembly {
            sstore(slot, a)
        }
    }

    function _get(bytes32 slot) internal view returns (address a) {
        assembly {
            a := sload(slot)
        }
    }

    fallback() external payable {
        address impl = _get(IMPL_SLOT);
        assembly {
            calldatacopy(0, 0, calldatasize())
            let ok := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch ok
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
