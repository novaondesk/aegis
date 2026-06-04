// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// Minimal OZ-compatible ECDSA shim for the Ethernaut wargame harness.
/// Faithful to OpenZeppelin's recover(): supports 65-byte (r,s,v) and 64-byte EIP-2098 compact
/// (r, vs) signatures, rejects high-s (malleability) and the zero address. The compact-form support
/// is exactly what the `Forger` level abuses (same recovery, different bytes => bypasses a
/// keccak(signature) replay guard).
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS
    }

    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            // EIP-2098 compact: r ++ vs, where vs packs s (low 255 bits) and the parity bit (top bit).
            bytes32 r;
            bytes32 vs;
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            uint8 v = uint8((uint256(vs) >> 255) + 27);
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address, RecoverError) {
        // reject high-s (EIP-2 malleability)
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }
        return (signer, RecoverError.NoError);
    }

    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address signer, RecoverError err) = tryRecover(hash, signature);
        _throw(err);
        return signer;
    }

    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address signer, RecoverError err) = tryRecover(hash, v, r, s);
        _throw(err);
        return signer;
    }

    function _throw(RecoverError err) private pure {
        if (err == RecoverError.NoError) return;
        if (err == RecoverError.InvalidSignatureLength) revert("ECDSA: invalid signature length");
        if (err == RecoverError.InvalidSignatureS) revert("ECDSA: invalid signature 's' value");
        revert("ECDSA: invalid signature");
    }

    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", _itoa(s.length), s));
    }

    function _itoa(uint256 value) private pure returns (bytes memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return buffer;
    }
}
