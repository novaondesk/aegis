// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Minimal IERC20 (OZ-compatible surface) — shim so the vendored Dex level compiles without pulling
// the full OpenZeppelin tree. Faithful semantics; the Dex bug is in its pricing math, not here.
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
