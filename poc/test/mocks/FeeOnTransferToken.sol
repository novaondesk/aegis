// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Minimal fee-on-transfer token: transferFrom burns a 10% fee, so the recipient receives less
/// than `amount`. (transfer() is fee-free here to keep the PoC's withdraw path clean.)
contract FeeOnTransferToken {
    string public name = "FeeToken";
    string public symbol = "FEE";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public constant FEE_BPS = 1000; // 10%

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) allowance[from][msg.sender] = a - amount;
        balanceOf[from] -= amount;
        uint256 fee = (amount * FEE_BPS) / 10000;
        uint256 received = amount - fee;
        balanceOf[to] += received;
        totalSupply -= fee; // burn the fee
        return true;
    }
}
