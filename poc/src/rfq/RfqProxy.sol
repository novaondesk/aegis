// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}

/// RFQ swap proxy access-control failure (TrustedVolumes, ~$6.7M, 2026-05-06). The proxy fills
/// signed swap orders from its own inventory, trusting any order signed by an address in
/// `authorizedSigners`. The setter that manages that allow-list was left `public` with no access
/// control, so an attacker added their own address as an authorized signer and then signed orders
/// that drained the inventory. Fix: gate the setter with onlyOwner.
///
/// See docs/exploits/trustedvolumes-rfq-2026-05-06.md

abstract contract RfqBase {
    address public owner;
    IERC20 public immutable token;
    mapping(address => bool) public authorizedSigners;

    constructor(IERC20 t) {
        owner = msg.sender;
        token = t;
    }

    function _setAuthorizedSigner(address signer, bool status) internal {
        authorizedSigners[signer] = status;
    }

    function setAuthorizedSigner(address signer, bool status) external virtual;

    /// Fill `amountOut` of inventory to `to` if the order is signed by an authorized signer.
    function executeSwap(address to, uint256 amountOut, uint256 nonce, uint8 v, bytes32 r, bytes32 s)
        external
    {
        bytes32 h = keccak256(abi.encodePacked(address(this), to, amountOut, nonce));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", h));
        address signer = ecrecover(ethHash, v, r, s);
        require(authorizedSigners[signer], "unauthorized signer");
        token.transfer(to, amountOut);
    }
}

/// VULNERABLE: the allow-list setter has no access control.
contract VulnerableRfq is RfqBase {
    constructor(IERC20 t) RfqBase(t) {}

    function setAuthorizedSigner(address signer, bool status) external override {
        _setAuthorizedSigner(signer, status); // BUG: anyone can authorize a signer
    }
}

/// SAFE: only the owner manages the signer allow-list.
contract SafeRfq is RfqBase {
    constructor(IERC20 t) RfqBase(t) {}

    function setAuthorizedSigner(address signer, bool status) external override {
        require(msg.sender == owner, "not owner");
        _setAuthorizedSigner(signer, status);
    }
}
