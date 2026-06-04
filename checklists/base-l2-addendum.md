# Base L2 Addendum Checklist

Supplement to `master-checklist.md` for protocols deployed on Base (OP-Stack L2).
Walk this against any Base-deployed contract during review.

Legend: 🤖 = an automated tool/rule can flag candidates · 👁 = needs human judgment.

---

## Sequencer Uptime & Oracle Freshness 👁🤖

### Sequencer Downtime Detection
- [ ] Does the protocol check the **Chainlink sequencer uptime feed** before trusting prices?
  - **Code smell:** Direct oracle price read without sequencer status check
  - **Exploit:** Stale prices during sequencer downtime → incorrect liquidations, unfair pricing
  - **Mitigation:** Query sequencer feed, implement grace period after sequencer recovery
  - **Reference:** [Chainlink L2 Sequencer Feeds](https://docs.chain.link/data-feeds/l2-sequencer-feeds)

### Price Staleness on L2
- [ ] Are oracle prices validated for freshness with L2-appropriate intervals?
  - **Code smell:** Using L1 staleness thresholds on L2 (block times differ)
  - **Exploit:** Stale prices accepted because L2 block time ≠ L1 block time
  - **Mitigation:** Use timestamp-based staleness checks, not block-based

### Sequencer Recovery Grace Period
- [ ] Is there a grace period after sequencer recovery before accepting prices?
  - **Code smell:** Immediate price acceptance after sequencer comes back online
  - **Exploit:** Mass liquidations at stale prices the moment sequencer resumes
  - **Mitigation:** Implement time-based grace period (e.g., 1 hour) after sequencer recovery

---

## Cross-Domain Messaging 👁

### xDomainMessageSender Verification
- [ ] Is `xDomainMessageSender` verified to be the expected L1 contract?
  - **Code smell:** Cross-domain message handling without sender verification
  - **Exploit:** Spoofed cross-domain messages from malicious L1 contracts
  - **Mitigation:** Verify `xDomainMessageSender` matches expected L1 address

### Address Aliasing (L1→L2)
- [ ] Is address aliasing handled for L1→L2 contract calls?
  - **Code smell:** Direct address comparison without accounting for alias offset
  - **Exploit:** L1 contract address ≠ L2 aliased address → auth bypass
  - **Mitigation:** Apply alias offset (`0x1111000000000000000000000000000000001111`) when comparing

### Cross-Domain Message Replay
- [ ] Are cross-domain messages protected against replay attacks?
  - **Code smell:** No nonce tracking or message deduplication
  - **Exploit:** Replay of legitimate cross-domain messages
  - **Mitigation:** Track processed message nonces, reject duplicates

### Cross-Domain Merkle Proof Verification
- [ ] For cross-chain bridges using Merkle proofs: Is the verification based on a
  well-audited library (OpenZeppelin MerkleProof)? Are roots sourced from authenticated
  validator attestations? Can proofs be forged?
  - **Code smell:** Custom Merkle verification without library; root stored without signature check
  - **Exploit:** Verus Bridge ($11.6M, May 2026) — forged Merkle proofs accepted as valid
    cross-chain withdrawal authorization. Similar to Wormhole/Nomad pattern.
  - **Mitigation:** Use OpenZeppelin MerkleProof; validate roots against signed attestations;
    implement guardian watchtower for suspicious withdrawals

---

## Block & Time Semantics 👁

### L2 Block Time Assumptions
- [ ] Does the protocol account for Base's ~2s block time (not L1's ~12s)?
  - **Code smell:** Using L1 block time assumptions for time-sensitive logic
  - **Exploit:** Time-dependent logic (auctions, vesting) behaves incorrectly
  - **Mitigation:** Use `block.timestamp` for time-sensitive operations, not `block.number`

### Cross-Chain Timing
- [ ] Is `block.number` used for cross-chain coordination (incorrect on L2)?
  - **Code smell:** Comparing L2 block numbers with L1 or other L2s
  - **Exploit:** Cross-chain sync failures, incorrect ordering assumptions
  - **Mitigation:** Use timestamps or cross-chain messaging for coordination

---

## Gas Economics 👁

### Cheap Gas Griefing
- [ ] Does the protocol account for significantly cheaper gas on Base vs L1?
  - **Code smell:** Unbounded loops, storage-heavy operations without gas limits
  - **Exploit:** Griefing attacks that are economical on L2 but not L1
  - **Mitigation:** Add gas limits to loops, consider storage costs in L2 context

### Gas Price Manipulation
- [ ] Is gas price used for any economic calculations (unreliable on L2)?
  - **Code smell:** Using `tx.gasprice` for fee calculations or priority logic
  - **Exploit:** Gas price manipulation on L2 (sequencer-controlled)
  - **Mitigation:** Don't rely on gas price for economic logic on L2

---

## Token Assumptions 👁

### Native vs Bridged USDC
- [ ] Does the protocol distinguish between native USDC and bridged USDC.e on Base?
  - **Code smell:** Assuming all USDC is the same contract
  - **Exploit:** Different decimals (6 vs 6 but different contracts), different mint authorities
  - **Mitigation:** Verify token contract addresses, not just symbols

### Fee-on-Transfer / Rebasing Tokens
- [ ] Are FoT/rebasing tokens handled correctly on Base?
  - **Code smell:** Assuming `transfer(amount)` results in `balance += amount`
  - **Exploit:** Incorrect accounting for FoT tokens
  - **Mitigation:** Check balance before/after transfer, use `SafeERC20`

### OP-Stack Predeploys
- [ ] Does the protocol interact with OP-Stack predeploy contracts correctly?
  - **Code smell:** Assuming predeploy addresses are same as L1
  - **Exploit:** Interacting with wrong contracts on L2
  - **Mitigation:** Use official OP-Stack predeploy addresses

---

## Withdrawal & Finalization 👁

### 7-Day Withdrawal Window
- [ ] Does the protocol account for the 7-day withdrawal finalization period?
  - **Code smell:** Assuming L2→L1 withdrawals are instant
  - **Exploit:** Users locked out of funds during finalization
  - **Mitigation:** Clearly communicate withdrawal delays, handle pending state

### Fault Proof Assumptions
- [ ] Is the protocol's security model compatible with OP-Stack's fault proof system?
  - **Code smell:** Assuming instant finality on L2
  - **Exploit:** Reliance on state that could be challenged during dispute period
  - **Mitigation:** Design for optimistic assumptions with dispute period awareness

---

## L2-Specific Attack Vectors 👁

### Sequencer MEV
- [ ] Does the protocol account for sequencer-controlled transaction ordering?
  - **Code smell:** Assuming fair transaction ordering on L2
  - **Exploit:** Sequencer can reorder transactions for MEV extraction
  - **Mitigation:** Use commit-reveal schemes, batch auctions, or private mempools

### L1→L2 Message Failure
- [ ] Does the protocol handle failed L1→L2 message deliveries gracefully?
  - **Code smell:** Assuming cross-chain messages always succeed
  - **Exploit:** Stuck funds, broken state if message fails
  - **Mitigation:** Implement retry mechanisms, timeout handling, user recovery paths

---

## Cross-Chain Vault & TSS Security 👁

### Threshold Signature Key Management
- [ ] 👁 If the protocol uses TSS (GG20, FROST, DKLS) for cross-chain vault management:
  Is the TSS library current with upstream security patches? Check for CVE-2023-33241 /
  TSSHOCK in any GG20 implementation.
  - **Code smell:** Forked TSS library without tracking upstream security releases
  - **Exploit:** Malicious co-signer registers malformed Paillier modulus, extracts key
    share residues from signing rounds, reconstructs vault private key
  - **THORChain: $10.8M across 10 chains including Base — tss-lib fork was 3 years
    behind upstream, skipped MOD/FAC proof checks**
  - **Mitigation:** Track upstream releases, verify MOD/FAC proofs in key generation,
    consider migrating to newer schemes (DKLS, FROST)

### Multi-Chain Drain Vectors
- [ ] 👁 For protocols with vaults on Base and other chains: Can a single compromised
  key authorize outbound transactions on all chains simultaneously? Is there per-chain
  quorum or rate limiting?
  - **Code smell:** Single TSS key controls vaults on multiple chains with no per-chain
    authorization checks
  - **Exploit:** Compromising one key drains all chains atomically
  - **THORChain: attacker signed unauthorized outbound txs across 10 chains from one
    compromised vault key — no per-chain quorum**
  - **Mitigation:** Per-chain quorum requirements, rate limits on outbound volume,
    anomaly detection on unusual withdrawal patterns

---

## Sources
- [OP Stack Docs: Cross-Domain Overview](https://docs.optimism.io/op-stack/bridging/cross-domain)
- [OP Stack Specs: Messengers](https://specs.optimism.io/protocol/messengers.html)
- [Chainlink: L2 Sequencer Uptime Feeds](https://docs.chain.link/data-feeds/l2-sequencer-feeds)
- [Medium: L2 Sequencer and Stale Oracle Prices Bug](https://medium.com/@lopotras/l2-sequencer-and-stale-oracle-prices-bug-54a749417277)
- [Code4rena: GoodEntry Findings — L2 Sequencer Check](https://github.com/code-423n4/2023-08-goodentry-findings/issues/503)
- [CryptoHawking: Oracle Manipulation — Stale Chainlink Feeds](https://www.cryptohawking.com/blog/oracle-manipulation-chainlink-staleness)
- [Chainstack: Base RPC Providers 2026](https://chainstack.com/base-rpc-providers-2026/)
- [Messari: State of the OP Stack Q1 2026](https://messari.io/report/state-of-the-op-stack-q1-2026)

### MMR Verifier Correctness (Bridge Proof Verification)
- [ ] For bridges using MMR (Merkle Mountain Range) verification: Does the verifier
  reject out-of-bounds leaf indices? Are duplicate leaf indices forbidden? Is there a
  post-loop check that all provided leaves were consumed? Are empty/trailing proofs
  rejected? Is the challenge/dispute period non-zero?
  - **Code smell:** MMR verifier that skips unconsumed leaves without checking; no
    duplicate index rejection; challengePeriod set to zero
  - **Exploit:** Hyperbridge ($237K extracted, 1B tokens minted, April 2026) — out-of-bounds
    leaf silently skipped by MMR peak loop, attacker forged cross-chain message to seize
    admin+minter on bridged DOT. Same bug class found in 3 independent Merkle libraries.
  - **Mitigation:** Add `if (leafIter.length != 0) revert OutOfBoundsLeaves()` after peak
    loop; require strictly increasing leaf indices; reject empty proofs; enforce non-zero
    challengePeriod; use continuous structural fuzzing (Polytope Labs harnesses)
