// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Bridge deposit credits an asset for a token address that has no code. A low-level
/// `transferFrom` call to an EOA / non-existent contract returns `success == true` with empty
/// returndata (the EVM treats a call to a codeless address as a no-op success), so the bridge
/// believes it received funds and credits the bridged balance — while nothing actually moved.
/// This is the Qubit qBridge-class bug (~$80M, Jan 2022). Fix: require code at the token address
/// (and/or a token allow-list), then verify the transfer.
///
/// See docs/exploits/bridge-deposit-no-code-token.md

/// VULNERABLE: trusts the boolean from a raw call without checking the token has code.
contract VulnerableBridge {
    mapping(address => uint256) public bridgedBalance; // claimable on the destination chain

    function deposit(address token, uint256 amount) external {
        (bool ok, bytes memory ret) = token.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)", msg.sender, address(this), amount
            )
        );
        // BUG: a codeless `token` returns (true, "") -> this passes without moving any tokens.
        require(ok && (ret.length == 0 || abi.decode(ret, (bool))), "transfer failed");
        bridgedBalance[msg.sender] += amount;
    }
}

/// SAFE: require the token address to be a contract (and ideally allow-listed), then verify.
contract SafeBridge {
    mapping(address => uint256) public bridgedBalance;
    mapping(address => bool) public allowed;

    constructor(address[] memory tokens) {
        for (uint256 i = 0; i < tokens.length; i++) allowed[tokens[i]] = true;
    }

    function deposit(address token, uint256 amount) external {
        require(allowed[token], "token not allow-listed");
        require(token.code.length > 0, "token has no code");
        (bool ok, bytes memory ret) = token.call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)", msg.sender, address(this), amount
            )
        );
        require(ok && (ret.length == 0 || abi.decode(ret, (bool))), "transfer failed");
        bridgedBalance[msg.sender] += amount;
    }
}
