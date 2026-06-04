// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Meta-transaction `_msgSender()` spoofing (ERC-2771 trusted-forwarder trust).
///
/// A contract that trusts a forwarder reads the *logical* caller from the last 20 bytes of
/// calldata (the ERC-2771 `_msgSender()` convention). That is only safe if the forwarder
/// **authenticates** the address it appends. A forwarder that forwards an arbitrary `from`
/// without verifying a signature from `from` lets anyone act as anyone — every `_msgSender()`
/// auth check downstream is spoofable. (DVD "Naive Receiver" is this class: a `multicall` lets the
/// attacker append the fee-receiver's address and `withdraw` the pool.)
///
/// See docs/exploits/meta-tx-msgsender-spoof.md

/// Target that uses ERC-2771 `_msgSender()` for authorization. It trusts a single forwarder.
contract Vault {
    address public immutable trustedForwarder;
    mapping(address => uint256) public balances;

    constructor(address forwarder) {
        trustedForwarder = forwarder;
    }

    function deposit(address who) external payable {
        balances[who] += msg.value;
    }

    /// ERC-2771: if called by the trusted forwarder, the real sender is appended to calldata.
    function _msgSender() internal view returns (address signer) {
        if (msg.sender == trustedForwarder && msg.data.length >= 20) {
            assembly {
                signer := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            signer = msg.sender;
        }
    }

    /// Debits the *authorized* account (`_msgSender()`) but pays a caller-chosen recipient. Auth is
    /// entirely `_msgSender()`, so spoofing it lets an attacker debit a victim and pay themselves.
    function withdraw(uint256 amount, address to) external {
        address who = _msgSender();
        require(balances[who] >= amount, "insufficient");
        balances[who] -= amount;
        (bool ok,) = payable(to).call{value: amount}("");
        require(ok, "send failed");
    }
}

/// VULNERABLE forwarder: appends `from` to the call without ever proving `from` authorized it.
/// Anyone can impersonate anyone downstream.
contract VulnerableForwarder {
    function execute(address target, address from, bytes calldata data) external returns (bytes memory) {
        // BUG: no signature / nonce check on `from` — attacker passes any victim address.
        (bool ok, bytes memory ret) = target.call(abi.encodePacked(data, from));
        require(ok, "forward failed");
        return ret;
    }
}

/// SAFE forwarder: only appends `from` after verifying an EIP-712 signature from `from` over the
/// request (binds the relayed action to the real account; nonces stop replay).
contract SafeForwarder {
    bytes32 public constant REQ_TYPEHASH =
        keccak256("ForwardRequest(address from,address target,uint256 nonce,bytes data)");
    bytes32 public immutable domainSeparator;
    mapping(address => uint256) public nonces;

    constructor() {
        domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)"),
                keccak256("SafeForwarder"),
                block.chainid,
                address(this)
            )
        );
    }

    function execute(address target, address from, bytes calldata data, bytes calldata sig)
        external
        returns (bytes memory)
    {
        bytes32 structHash = keccak256(abi.encode(REQ_TYPEHASH, from, target, nonces[from]++, keccak256(data)));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        require(_recover(digest, sig) == from, "bad signature");

        (bool ok, bytes memory ret) = target.call(abi.encodePacked(data, from));
        require(ok, "forward failed");
        return ret;
    }

    function _recover(bytes32 digest, bytes calldata sig) internal pure returns (address) {
        require(sig.length == 65, "bad sig len");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        return ecrecover(digest, v, r, s);
    }
}
