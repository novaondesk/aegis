# 2026-06-07 — ATOHook Storage Slot Collision (Solady ReentrancyGuard)

## Done
- Studied ATOHook storage slot collision exploit (SlowMist TI alert, 2026-06-07)
- Loss: 14.41 ETH from Ethereum mainnet
- Root cause: `mapping(address => uint256) rewards` entry slot collided with Solady's `_REENTRANCY_GUARD_SLOT`
- Attacker deployed contract at CREATE2 address where `keccak256(addr, baseSlot) == guardSlot`
- `nonReentrant` modifier's sentinel write inflated `rewards[attacker]`, enabling repeated ETH drainage

## PoC
- Built Foundry PoC: `poc/test/StorageSlotCollisionAtoHook.t.sol`
- Vulnerable contract inlines Solady's ReentrancyGuard assembly logic
- Demonstrates collision via `vm.store` (simulates what the real guard write does)
- Tests: single drain, repeated drain (5 iterations), collision slot calculation, safe variant
- All 4 tests pass

## Catalog + Checklist
- Added `ato-hook-storage-slot-collision` entry to `catalog/exploits.yaml` (status: coded)
- Added `SC-storage-layout-02` checklist item to `checklists/master-checklist.md`
- YAML validates cleanly

## Key Insight
- Solady's ReentrancyGuard uses a fixed slot (`0x929eee149b4bd21268`) — not truly random
- Any `mapping(address => ...)` with attacker-controlled keys can potentially collide
- The attacker searches CREATE2 salts until `keccak256(addr, baseSlot) == guardSlot`
- The guard's security write becomes a value-inflation oracle
- This is NOT a classic proxy collision — it's intra-contract between business logic and a security primitive

## Takeaway
- Storage layout validation must include library-reserved slots
- Mappings with attacker-controlled keys are high-risk for slot collisions
- The fix: use sequential storage for guards (OpenZeppelin pattern) or verify no mapping can collide
