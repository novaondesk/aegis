// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Vulnerable staking/rewards contract demonstrating Solady ReentrancyGuard storage collision.
/// @notice Simplified model of the ATOHook at 0xa10de71d... that lost ~14.4 ETH.
/// @dev Storage layout:
///   slot 0: owner (address)
///   slot 1: rewards mapping (address => uint256)
///   Solady's _REENTRANCY_GUARD_SLOT = 0x929eee149b4bd21268 (pseudo-random, assembly-only)
///
/// The collision: if keccak256(abi.encode(attackerAddr, 1)) == 0x929eee149b4bd21268,
/// then the nonReentrant modifier's sentinel write inflates rewards[attacker].
contract ATOHookVulnerable {
    // --- Storage layout matches the real ATOHook ---
    address public owner;                              // slot 0
    mapping(address => uint256) public rewards;        // slot 1

    // --- Solady ReentrancyGuard inlined (same logic, same slot) ---
    uint256 private constant _REENTRANCY_GUARD_SLOT = 0x929eee149b4bd21268;

    modifier nonReentrant() {
        assembly {
            if eq(sload(_REENTRANCY_GUARD_SLOT), address()) {
                mstore(0x00, 0xab143c06) // Reentrancy()
                revert(0x1c, 0x04)
            }
            sstore(_REENTRANCY_GUARD_SLOT, address()) // mark entered (slot = 0)
        }
        _;
        assembly {
            sstore(_REENTRANCY_GUARD_SLOT, codesize()) // mark not-entered (slot = codesize())
        }
    }

    constructor() {
        owner = msg.sender;
    }

    function earnRewards(address user, uint256 amount) external {
        rewards[user] += amount;
    }

    /// @notice Claim accrued ETH rewards — protected by nonReentrant.
    /// @dev The attack: nonReentrant writes sentinel to the guard slot.
    ///      If that slot collides with rewards[attacker], the payout is inflated.
    function getReward() external nonReentrant {
        uint256 amount = rewards[msg.sender];
        require(amount > 0, "no rewards");
        rewards[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "ETH transfer failed");
    }

    function rewardOf(address user) external view returns (uint256) {
        return rewards[user];
    }

    receive() external payable {}
}

/// @notice Safe variant: sequential storage slot for the guard, immune to mapping collisions.
contract ATOHookSafe {
    uint256 private _guardStatus;   // slot 0 — sequential, not keccak-derived
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    address public owner;                              // slot 1
    mapping(address => uint256) public rewards;        // slot 2

    modifier nonReentrant() {
        require(_guardStatus != _ENTERED, "ReentrancyGuard: reentrant call");
        _guardStatus = _ENTERED;
        _;
        _guardStatus = _NOT_ENTERED;
    }

    constructor() {
        owner = msg.sender;
        _guardStatus = _NOT_ENTERED;
    }

    function earnRewards(address user, uint256 amount) external {
        rewards[user] += amount;
    }

    function getReward() external nonReentrant {
        uint256 amount = rewards[msg.sender];
        require(amount > 0, "no rewards");
        rewards[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "ETH transfer failed");
    }

    function rewardOf(address user) external view returns (uint256) {
        return rewards[user];
    }

    receive() external payable {}
}
