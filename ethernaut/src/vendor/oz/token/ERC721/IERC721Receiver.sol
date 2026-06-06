// SPDX-License-Identifier: MIT
// Minimal shim of OpenZeppelin token/ERC721/IERC721Receiver.
pragma solidity ^0.8.20;

interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}
