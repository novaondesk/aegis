// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Insecure on-chain randomness: a lottery derives the winner from block variables
/// (timestamp/prevrandao/blockhash) that are visible — and partly controllable — at execution
/// time. An attacker contract recomputes the exact same value in the same transaction and only
/// enters when it would win, so it never loses. Fix: external randomness (Chainlink VRF) or
/// commit-reveal, where the outcome is unknown when the entry is locked.
///
/// See docs/exploits/insecure-randomness.md

/// VULNERABLE: winner decided from block vars at play() time.
contract VulnerableLottery {
    uint256 public prize;

    constructor() payable {
        prize = msg.value;
    }

    function play() external payable returns (bool win) {
        require(msg.value == 1 ether, "ticket = 1 ether");
        // BUG: predictable — any caller can compute this before calling.
        uint256 rand =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % 2;
        if (rand == 0) {
            win = true;
            uint256 pot = prize + msg.value;
            prize = 0;
            (bool ok,) = msg.sender.call{value: pot}("");
            require(ok, "payout failed");
        }
    }

    receive() external payable {}
}

/// SAFE: entries are locked first; the winner is chosen later from a random word supplied by a
/// trusted VRF coordinator. At play() time there is no observable randomness to condition on, and
/// only the coordinator can settle.
contract SafeLottery {
    address public immutable vrf;
    address[] public players;
    bool public open = true;

    constructor(address _vrf) payable {
        vrf = _vrf;
    }

    function play() external payable {
        require(open && msg.value == 1 ether, "closed / ticket = 1 ether");
        players.push(msg.sender); // commit blind — outcome doesn't exist yet
    }

    function settle(uint256 randomWord) external returns (address winner) {
        require(msg.sender == vrf, "only vrf");
        require(open, "already settled");
        open = false;
        winner = players[randomWord % players.length];
        (bool ok,) = winner.call{value: address(this).balance}("");
        require(ok, "payout failed");
    }

    receive() external payable {}
}
