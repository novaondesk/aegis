// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Calldata / ABI smuggling (SC05 — validating a different byte range than you execute).
///
/// A gatekeeper that allow-lists a function by reading the target selector from a **fixed calldata
/// position** — assuming canonical ABI encoding — and then forwarding a **dynamic `bytes` param**
/// can be tricked. ABI offsets are attacker-controlled, so the bytes at the checked position and
/// the bytes that actually get executed are two different things: the attacker parks an allowed
/// selector where the guard looks while the forwarded `actionData` invokes a forbidden function.
/// (DVD "ABI Smuggling"; Ethernaut "Switch"/"HigherOrder" are the same decouple-the-pointer trick.)
///
/// Fix: validate the *same* bytes you execute — read the selector from `actionData[:4]`, never from
/// a hard-coded `calldataload` offset.
///
/// See docs/exploits/calldata-abi-smuggling.md

/// VULNERABLE: reads the guarded selector from a hard-coded msg.data offset (0x44), which only
/// coincides with the forwarded selector under canonical encoding.
contract VulnerableSelfAuthVault {
    bytes4 internal constant DEPOSIT = bytes4(keccak256("deposit()"));
    mapping(bytes4 => bool) public allowed;

    constructor() payable {
        allowed[DEPOSIT] = true; // only deposit() is permitted through execute()
    }

    modifier onlyThis() {
        require(msg.sender == address(this), "only this");
        _;
    }

    function deposit() external payable {}

    /// Privileged: guarded only by execute()'s selector allow-list (no own access control).
    function sweepFunds(address to) external onlyThis {
        (bool ok,) = payable(to).call{value: address(this).balance}("");
        require(ok, "sweep failed");
    }

    function execute(bytes calldata actionData) external returns (bytes memory) {
        bytes4 selector;
        assembly {
            // BUG: fixed offset — assumes the canonical bytes-content position. The attacker can
            // move the real `actionData` elsewhere via a non-standard ABI offset.
            selector := calldataload(0x44)
        }
        require(allowed[selector], "forbidden selector");
        (bool ok, bytes memory ret) = address(this).call(actionData);
        require(ok, "exec failed");
        return ret;
    }
}

/// SAFE: validates the selector of the bytes it actually forwards.
contract SafeSelfAuthVault {
    bytes4 internal constant DEPOSIT = bytes4(keccak256("deposit()"));
    mapping(bytes4 => bool) public allowed;

    constructor() payable {
        allowed[DEPOSIT] = true;
    }

    modifier onlyThis() {
        require(msg.sender == address(this), "only this");
        _;
    }

    function deposit() external payable {}

    function sweepFunds(address to) external onlyThis {
        (bool ok,) = payable(to).call{value: address(this).balance}("");
        require(ok, "sweep failed");
    }

    function execute(bytes calldata actionData) external returns (bytes memory) {
        require(actionData.length >= 4, "no selector");
        bytes4 selector = bytes4(actionData[:4]); // the selector we are about to run
        require(allowed[selector], "forbidden selector");
        (bool ok, bytes memory ret) = address(this).call(actionData);
        require(ok, "exec failed");
        return ret;
    }
}
