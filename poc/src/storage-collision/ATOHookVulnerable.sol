// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Vulnerable staking/rewards contract — Solady ReentrancyGuard storage collision model.
/// @notice Simplified model of the ATOHook at 0xa10de71d... that lost ~14.4 ETH.
/// @dev The guard slot is a constructor parameter (modeled as Solady's fixed slot).
///      When it collides with a mapping entry, the nonReentrant write inflates the balance.
///
/// Storage layout:
///   slot 0: owner
///   slot 1: rewards mapping (address => uint256)
///   _GUARD_SLOT (parameter): Solady sentinel slot
///
/// The real incident used sentinel 0xffffffffffffff per call (14.4 ETH / 200 calls = 72057594037927935 wei
/// = 2^56 - 1). The modifier writes this on ENTRY (the "locked" state). On EXIT, it writes a
/// DIFFERENT value to "unlock" the guard for the next call. Because the guard slot collides
/// with rewards[attacker], the body reads the entry sentinel as the reward balance.
///
/// Guard flow:
///   Check:  if sload(slot) == entrySentinel → revert (already inside a guarded call)
///   Entry:  sstore(slot, entrySentinel)      → overwrites rewards[attacker] = entrySentinel
///   Body:   amount = rewards[msg.sender]     → reads entrySentinel, drains it as ETH
///   Exit:   sstore(slot, exitSentinel)       → "unlocks" (different value from entry)
///
/// Next call: sload(slot) == exitSentinel ≠ entrySentinel → passes check → repeats.
contract ATOHookVulnerable {
    address public owner;                           // slot 0
    mapping(address => uint256) public rewards;     // slot 1

    /// @dev The reentrancy guard slot — modeled as Solady's _REENTRANCY_GUARD_SLOT.
    uint256 private immutable _GUARD_SLOT;

    /// @dev Entry sentinel: written on entry, checked against on entry.
    ///      In the real incident, this was 0xffffffffffffff (2^56 - 1).
    uint256 private immutable _ENTRY_SENTINEL;

    /// @dev Exit sentinel: written on exit. Must differ from entry sentinel.
    ///      In real Solady, this is codesize(). In the real ATOHook, it may have been
    ///      address(0) or another value. The key is that it differs from _ENTRY_SENTINEL.
    uint256 private immutable _EXIT_SENTINEL;

    constructor(uint256 guardSlot_, uint256 entrySentinel_, uint256 exitSentinel_) {
        owner = msg.sender;
        _GUARD_SLOT = guardSlot_;
        _ENTRY_SENTINEL = entrySentinel_;
        _EXIT_SENTINEL = exitSentinel_;
    }

    modifier nonReentrant() {
        uint256 slot = _GUARD_SLOT;
        uint256 entrySentinel = _ENTRY_SENTINEL;
        uint256 exitSentinel = _EXIT_SENTINEL;
        assembly {
            // Guard check: if slot holds entrySentinel, we're already inside → revert
            if eq(sload(slot), entrySentinel) {
                mstore(0x00, 0xab143c06) // Reentrancy()
                revert(0x1c, 0x04)
            }
            // Mark entered: write entrySentinel to the slot
            sstore(slot, entrySentinel)
        }
        _;
        assembly {
            // Mark not-entered: write exitSentinel (different value)
            sstore(slot, exitSentinel)
        }
    }

    function earnRewards(address user, uint256 amount) external {
        rewards[user] += amount;
    }

    /// @notice Claim accrued ETH rewards — protected by nonReentrant.
    /// @dev The exploit: nonReentrant writes _ENTRY_SENTINEL to _GUARD_SLOT.
    ///      If _GUARD_SLOT collides with rewards[msg.sender], the body reads
    ///      _ENTRY_SENTINEL as the reward balance and pays it out as ETH.
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
