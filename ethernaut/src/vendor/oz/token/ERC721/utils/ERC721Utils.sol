// SPDX-License-Identifier: MIT
// Minimal shim of OpenZeppelin v5.x token/ERC721/utils/ERC721Utils — faithful to the
// onERC721Received acceptance check (the reentrancy surface the level relies on).
pragma solidity ^0.8.20;

import {IERC721Receiver} from "../IERC721Receiver.sol";

library ERC721Utils {
    error ERC721InvalidReceiver(address receiver);

    /// If `to` has code, call its onERC721Received and require the magic return value.
    /// (For a codeless EOA it is a no-op — same as OpenZeppelin.)
    function checkOnERC721Received(
        address operator,
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(operator, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(to);
                } else {
                    assembly ("memory-safe") {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }
}
