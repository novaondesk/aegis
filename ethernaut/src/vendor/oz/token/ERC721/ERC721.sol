// SPDX-License-Identifier: MIT
// Minimal shim of OpenZeppelin v5.x token/ERC721/ERC721 — only the surface the levels use:
// name/symbol, balanceOf, ownerOf, the virtual _update hook, and _mint (which routes through
// _update so an override like UniqueNFT's transfer-block applies). Faithful to v5 _update/_mint.
pragma solidity ^0.8.20;

abstract contract ERC721 {
    string private _name;
    string private _symbol;

    mapping(uint256 tokenId => address) private _owners;
    mapping(address owner => uint256) private _balances;

    error ERC721InvalidOwner(address owner);
    error ERC721NonexistentToken(uint256 tokenId);
    error ERC721InvalidSender(address sender);
    error ERC721InvalidReceiver(address receiver);

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function balanceOf(address owner) public view returns (uint256) {
        if (owner == address(0)) revert ERC721InvalidOwner(address(0));
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) revert ERC721NonexistentToken(tokenId);
        return owner;
    }

    function _ownerOf(uint256 tokenId) internal view returns (address) {
        return _owners[tokenId];
    }

    /// v5 core mutation hook. Returns the previous owner (`from`). Overridable.
    function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
        address from = _ownerOf(tokenId);
        auth; // (auth/approval checks omitted — not exercised by the levels)

        if (from != address(0)) {
            unchecked {
                _balances[from] -= 1;
            }
        }
        if (to != address(0)) {
            unchecked {
                _balances[to] += 1;
            }
        }
        _owners[tokenId] = to;
        return from;
    }

    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert ERC721InvalidReceiver(address(0));
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner != address(0)) revert ERC721InvalidSender(address(0));
    }
}
