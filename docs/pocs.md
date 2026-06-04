---
title: PoCs & detectors
nav_order: 6
---

# PoCs & detectors
{: .no_toc }

Every detector is backed by a runnable proof. Model PoCs live in [`poc/`](https://github.com/novaondesk/aegis/blob/main/poc) as a minimal
**`Vulnerable<X>` + `Safe<X>` + exploit test** — the exploit profits / breaks the invariant on the
vulnerable contract, and the same test shows the fix holds. Real-incident replays live in
[`sim/`](https://github.com/novaondesk/aegis/blob/main/sim). Run all: `cd poc && forge test`.
{: .fs-5 .fw-300 }

1. TOC
{:toc}

---

## erc4626-inflation
{: #erc4626-inflation }

**Class** SC07/SC02 · **Chains** evm · **Status** `coded`

A vault that prices shares off asset.balanceOf(this) and mints the first depositor 1:1 with no virtual offset lets that depositor donate tokens to inflate price-per-share, so a later depositor's round-down share math mints them fewer shares than fair; the attacker redeems the remainder.

**Invariant:** shares are priced fairly; no external donation can shift price-per-share between depositors

```
cd poc && forge test --match-contract InflationAttack -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/InflationAttack.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/erc4626-inflation-attack.md)

---

## read-only-reentrancy
{: #read-only-reentrancy }

**Class** SC08 · **Chains** evm · **Status** `coded`

A pool updates supply before an external call but updates its reserve after, so during the callback a VIEW function returns an inconsistent (inflated) price. A consumer that reads that view as a collateral oracle during the callback lets the attacker over-borrow. nonReentrant on state-changing functions does NOT protect the view.

**Invariant:** a pool's price view is never read while the pool's internal state is mid-update

```
cd poc && forge test --match-contract ReadOnlyReentrancy -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/ReadOnlyReentrancy.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/read-only-reentrancy.md)

---

## balancer-v2-rounding
{: #balancer-v2-rounding }

**Class** SC07 · **Chains** evm/multi · **Status** `coded` · **Loss** $128,000,000

_upscale() always rounds down (mulDown) but the paired downscaling uses directional rounding; _swapGivenOut rounds the requested output down, then underestimates the required input. 65 micro-swaps (8-19 wei) in one batchSwap compounded the error, deflating the pool invariant D and the BPT price, which the attacker then redeemed at full value across 6 chains.

**Invariant:** the pool invariant D never decreases due to a round-trip swap; BPT price = D / totalSupply holds

```
cd poc && forge test --match-contract BalancerRounding -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/BalancerRounding.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/balancer-v2-rounding-2025-11-03.md)

---

## cashio-infinite-mint
{: #cashio-infinite-mint }

**Class** SC05/SC02 · **Chains** solana · **Status** `coded` · **Loss** $52,800,000

The brrr program validated that accounts matched each other but never validated the `mint` field on the Saber Arrow account — so an attacker built a parallel tree of fake accounts (fake bank -> fake swap -> fake LP) that passed every relative check, minting 2B CASH backed by worthless collateral. No trusted root: validation chains that never anchor to a known mint/program are meaningless.

**Invariant:** every minted unit of stablecoin is backed by collateral whose mint is a known, trusted token

```
cd poc && forge test --match-contract CashioInfiniteMint -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/CashioInfiniteMint.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/cashio-infinite-mint-2022-03-23.md)

---

## cetus-amm-overflow
{: #cetus-amm-overflow }

**Class** SC07/SC09 · **Chains** sui-move · **Status** `coded` · **Loss** $223,000,000

A single wrong constant in checked_shlw — mask 0xffff..f << 192 instead of 1 << 192 — let values in [2^192, 2^256-2^192) pass an overflow check. A crafted liquidity (~2^113) over a narrow tick range made an intermediate shift silently truncate (Move shifts are modular, unlike +/*/-), collapsing the token-amount to 1. Deposit 1 token, get a huge position, drain ~$223M.

**Invariant:** no input within type range causes an unchecked silent truncation in liquidity math

```
cd poc && forge test --match-contract CetusOverflow -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/CetusOverflow.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/cetus-amm-overflow-2025-05-22.md)

---

## loopscale-oracle-spot-price
{: #loopscale-oracle-spot-price }

**Class** SC03/SC02 · **Chains** solana · **Status** `coded` · **Loss** $5,800,000

Loopscale valued RateX PT collateral from a single liquidity-pool spot price with no TWAP, no multi-source aggregation, no staleness check, and no flash-loan-aware validation. Flash loans skewed the thin pool, the protocol mispriced collateral, and the attacker drained $5.8M (returned via whitehat bounty).

**Invariant:** reported collateral price cannot be moved materially within a single transaction

```
cd poc && forge test --match-contract LoopscaleOracle -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/LoopscaleOracle.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/loopscale-oracle-2025-04.md)

---

## loopscale-ratex-cpi
{: #loopscale-ratex-cpi }

**Class** SC03/SC02/SC05 · **Chains** solana · **Status** `coded` · **Loss** $5,800,000

The loan-health check CPI'd into a user-supplied "RateX" program to read PT exchange rates without validating it against the real RateX program id. The attacker deployed a malicious program that spoofed the interface and returned inflated PT prices, enabling massively undercollateralized loans.

**Invariant:** all cross-program calls target a known, validated program id

```
cd poc && forge test --match-contract LoopscaleCpi -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/LoopscaleCpi.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/loopscale-ratex-pricing-2025-04-26.md)

---

## mango-oracle-manipulation
{: #mango-oracle-manipulation }

**Class** SC03/SC02 · **Chains** solana · **Status** `coded` · **Loss** $114,000,000

MNGO (a thin governance token) was usable as cross-margin collateral at 100% weight with no circuit breakers or position limits. The attacker opened a huge MNGO-PERP long, spiked the MNGO oracle ~2,300% by buying on the same thin markets the oracle aggregated, then borrowed $116M against the inflated collateral. The code ran correctly; the economic design was the bug.

**Invariant:** borrowing power from any collateral is bounded by its real, manipulation-resistant liquidity

```
cd poc && forge test --match-contract MangoOracle -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/MangoOracle.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/mango-markets-oracle-manipulation.md)

---

## beanstalk-governance-flashloan
{: #beanstalk-governance-flashloan }

**Class** SC02/SC04 · **Chains** evm · **Status** `coded` · **Loss** $181,000,000

Governance computed voting power (Roots) from real-time Silo deposit balances rather than snapshots at proposal creation. The attacker flash-loaned ~$1B in stablecoins from Aave/Uniswap/SushiSwap, converted to Curve LP, deposited into Beanstalk's Silo for overwhelming Roots, voted on a pre-submitted malicious BIP-18 proposal, called emergencyCommit() with >67% supermajority, and drained all protocol assets — all in a single atomic transaction. Net profit ~$76M after flash-loan repayment.

**Invariant:** governance approval reflects long-term stakeholder will at proposal creation, not temporary flash-loan-acquired power

```
cd poc && forge test --match-contract BeanstalkGovernance -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/BeanstalkGovernance.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/beanstalk-governance-flashloan-2022-04-17.md) · [fork replay](https://github.com/novaondesk/aegis/blob/main/sim/test/BeanstalkGovFlashloan_2022_04.t.sol)

---

## rhea-finance-slippage
{: #rhea-finance-slippage }

**Class** SC02/SC07 · **Chains** near/multi · **Status** `coded` · **Loss** $18,400,000

**Invariant:** the validated minimum output must equal the actual terminal output of the swap route, not the sum of intermediate hop minimums

```
cd poc && forge test --match-contract RheaSlippage -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/RheaSlippage.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/rhea-finance-slippage-2026-04-16.md)

---

## trustedvolumes-access-control
{: #trustedvolumes-access-control }

**Class** SC02 · **Chains** evm · **Status** `coded` · **Loss** $6,700,000

TrustedVolumes' RFQ swap proxy had a setAuthorizedSigner(address, bool) function marked public with no access control modifier. The attacker called it to add themselves to the authorized signer whitelist, then created trade orders signed by their own key — the contract accepted them as legitimate. $6.7M drained in WETH, WBTC, USDT, USDC. Same attacker as the March 2025 1inch Fusion V1 exploit.

**Invariant:** only admin-controlled addresses can modify the authorized signer whitelist

```
cd poc && forge test --match-contract TrustedVolumesAccess -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/TrustedVolumesAccess.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/trustedvolumes-rfq-2026-05-06.md)

---

## verus-bridge-merkle-forgery
{: #verus-bridge-merkle-forgery }

**Class** SC02 · **Chains** evm/multi · **Status** `coded` · **Loss** $11,600,000

Verus-Ethereum bridge accepted forged Merkle proofs as valid cross-chain withdrawal authorization. Attacker extracted 103.6 tBTC, 1,625 ETH, and 147,000 USDC (~$11.6M). Pattern similar to 2022 Wormhole and Nomad bridge exploits. Attacker returned $8.5M after 1,350 ETH bounty negotiation.

**Invariant:** cross-chain withdrawal requires proof of deposit on source chain, verified against authenticated root

```
cd poc && forge test --match-contract VerusMerkleForgery -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/VerusMerkleForgery.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/verus-bridge-merkle-2026-05-17.md)

---

## thorchain-tss-gg20-key-extraction
{: #thorchain-tss-gg20-key-extraction }

**Class** X04 · **Chains** multi · **Status** `studied` · **Loss** $10,800,000

An attacker bonded as a THORChain node operator and registered a malformed Paillier modulus during GG20 key generation. Because THORChain's tss-lib fork skipped MOD/FAC proof checks (CVE-2023-33241), each signing round leaked key share residues. The attacker reconstructed the full vault private key and drained $10.8M across 10 chains.

**Invariant:** No single co-signer can extract the full TSS private key from signing ceremonies; all Paillier moduli are sound (product of two large primes with unknown factorization)

[case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/thorchain-tss-gg20-2026-05-15.md)

_Studied (deep-dive doc only — no runnable PoC; see the case study for why)._

---

## ekubo-callback-approval-drain
{: #ekubo-callback-approval-drain }

**Class** SC02/SC02-CB · **Chains** evm · **Status** `studied` · **Loss** $1,400,000

Ekubo's pay() function forwards arbitrary trailing calldata to the caller's callback and verifies only that Core's own token balance increased. A malicious callback contract (0x8ccb...) extracted a victim address and amount from the forwarded calldata, then called transferFrom(victim, Core, amount) using the victim's pre-existing unlimited approval. Core's balance check passed because the tokens arrived from the victim, not from the callback's own funds. The attacker withdrew 0.2 WBTC per iteration × 85 iterations = 17 WBTC ($1.4M). Ekubo Core's net balance was zero — the protocol was a drain rail, not the loss source. This is the same calldata-injection class as the SwapNet $17M exploit (Jan 2026).

**Invariant:** A flash-accounting callback must only repay debt using funds from the locker itself or from addresses that explicitly approved the callback for this purpose. The contract must not accept balance increases from arbitrary transferFrom calls against third-party standing approvals.

[case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/ekubo-callback-approval-drain-2026-05-05.md)

_Studied (deep-dive doc only — no runnable PoC; see the case study for why)._

---

## kelp-dao-layerzero-dvn-1-1
{: #kelp-dao-layerzero-dvn-1-1 }

**Class** X01/X01-BRIDGE · **Chains** ethereum/multi-chain · **Status** `coded` · **Loss** $292,000,000

Kelp DAO's rsETH bridge used a 1-of-1 DVN (Decentralized Verifier Network) configuration on LayerZero — only a single verifier needed to sign cross-chain messages. An attacker (Lazarus Group) compromised 2 of LayerZero's own RPC nodes, DDoS'd remaining nodes forcing failover to poisoned ones, and forged a cross-chain message. The single DVN accepted the forgery and the bridge released 116,500 rsETH ($292M). 47% of active LayerZero OApps used the same vulnerable 1/1 default config.

**Invariant:** Cross-chain message verification must require attestations from >=2 independent verifiers operating on separate infrastructure (different RPC endpoints, different operators, different admin keys), such that no single compromised entity can authorize a fraudulent transfer. Deployment scripts must reject configurations where requiredDVNs.length < 2.

```
cd poc && forge test --match-contract KelpDvnThreshold -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/KelpDvnThreshold.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/kelp-dao-layerzero-dvn-2026-04-18.md)

---

## ctoken-empty-market-exchange-rate
{: #ctoken-empty-market-exchange-rate }

**Class** SC07/SC02 · **Chains** evm · **Status** `coded`

A Compound V2-style cToken prices itself as exchangeRate = cash / totalSupply. In an empty/near-empty market the attacker mints 1 cToken, donates underlying directly to inflate the rate, and a later depositor's round-down mint yields zero cTokens while the attacker (still 100% of supply) redeems the victim's deposit. Distinct from the ERC-4626 vault case: the manipulable accounting is a lending market's exchange rate, and the trigger is an emptied/permissionlessly-listed market.

**Invariant:** no external token donation can shift price-per-share between deposits, and any non-dust deposit mints > 0 shares

```
cd poc && forge test --match-contract CTokenInflation -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/CTokenInflation.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/ctoken-empty-market-exchange-rate-2023-04.md)

---

## approval-drain-arbitrary-call
{: #approval-drain-arbitrary-call }

**Class** SC05/SC01 · **Chains** evm · **Status** `coded`

A swap/bridge router holds users' standing ERC20 approvals and forwards a caller-supplied target.call(data) to an "adapter". With target/data unrestricted, the attacker passes target = token, data = transferFrom(victim, attacker, amount); because the router is msg.sender and the victim approved it, every wallet with a live approval is drained. The high-frequency "arbitrary external call over standing approvals" confused-deputy class.

**Invariant:** a contract holding third-party approvals must only move those tokens via its own fixed logic; no attacker-chosen (target, selector) may reach a standing allowance

```
cd poc && forge test --match-contract ApprovalDrain -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/ApprovalDrain.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/approval-drain-arbitrary-call-2024-02.md) · [fork replay](https://github.com/novaondesk/aegis/blob/main/sim/test/SocketApprovalDrain_2024_01.t.sol)

---

## proxy-storage-collision
{: #proxy-storage-collision }

**Class** SC01 · **Chains** evm · **Status** `coded` · **Loss** $6,000,000

A delegatecall proxy keeps its admin/implementation pointers in low sequential storage slots, and the implementation declares state variables in those same slots. Because delegatecall executes against the proxy's storage, an implementation function that writes its slot-0 var overwrites the proxy admin, letting an attacker seize upgrade rights (Audius-class, 2022).

**Invariant:** no implementation state variable may occupy the same storage slot as the proxy's admin/implementation pointers

```
cd poc && forge test --match-contract ProxyCollision -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/ProxyCollision.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/proxy-storage-collision-2022-07.md) · [fork replay](https://github.com/novaondesk/aegis/blob/main/sim/test/AudiusGovTakeover_2022_07.t.sol)

---

## signature-replay-malleability
{: #signature-replay-malleability }

**Class** SC01 · **Chains** evm · **Status** `coded`

A function authorizes an action from an off-chain signature but binds no consumed nonce and no EIP-712 domain (so one signature is replayed to repeat the action, or reused across chains/forks), and uses raw ecrecover with no low-s/zero-address check (so a malleated n-s signature is a second valid signature for the same message, defeating byte-dedup).

**Invariant:** each authorizing signature is valid for exactly one action in one place (nonce + domain bound) and only canonical low-s form is accepted

```
cd poc && forge test --match-contract SignatureReplay -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/SignatureReplay.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/signature-replay-malleability.md)

---

## unprotected-privileged-fn
{: #unprotected-privileged-fn }

**Class** SC01 · **Chains** evm · **Status** `coded`

A state-changing privileged function (mint/burn/withdraw/setOwner/upgrade/initialize/pause/ setFee) is exposed with no access modifier, or an initialize has no once-guard. An attacker calls it to print supply, seize ownership, or drain funds. The largest DeFiHackLabs class by count; PAID Network (~$180M nominal) is the canonical ungated-mint case.

**Invariant:** every privileged state transition is reachable only by an authorized principal; one-shot initializers run exactly once

```
cd poc && forge test --match-contract UnprotectedPrivileged -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/UnprotectedPrivileged.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/unprotected-privileged-fn.md) · [fork replay](https://github.com/novaondesk/aegis/blob/main/sim/test/DaoMakerInitDrain_2021_09.t.sol)

---

## insecure-randomness
{: #insecure-randomness }

**Class** SC09 · **Chains** evm · **Status** `coded`

A contract derives a winner / rarity / selection from block variables (timestamp, prevrandao, blockhash, number). Anything the EVM reads, an attacker contract reads in the same tx, so it precomputes the outcome and only commits when it would win; proposers can also grind the values. Fix: Chainlink VRF or commit-reveal so the outcome is unknown at commit.

**Invariant:** a participant cannot compute or influence the draw at the moment they commit their entry

```
cd poc && forge test --match-contract InsecureRandomness -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/InsecureRandomness.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/insecure-randomness.md)

---

## weird-erc20-accounting
{: #weird-erc20-accounting }

**Class** SC02 · **Chains** evm · **Status** `coded`

A vault/pool credits the requested deposit amount, but a fee-on-transfer / deflationary / rebasing token delivers less than requested. Internal credited balances then exceed the tokens actually held, and late withdrawers are shorted. Fix: credit the measured balanceOf delta and use SafeERC20.

**Invariant:** sum of internally-credited balances never exceeds tokens actually held: sum(credited) <= balanceOf(this)

```
cd poc && forge test --match-contract WeirdErc20Accounting -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/WeirdErc20Accounting.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/weird-erc20-accounting.md)

---

## incorrect-reward-accounting
{: #incorrect-reward-accounting }

**Class** SC02 · **Chains** evm · **Status** `coded`

A reward farm pays pending = amount * accRewardPerShare - rewardDebt but fails to advance the user's rewardDebt checkpoint after payout, so pending recomputes to the same value and the same reward is harvested repeatedly until the pool is drained. Fix: update rewardDebt on every harvest/deposit/withdraw, after updatePool and settling pending.

**Invariant:** immediately after harvest, pending(user) == 0; cumulative rewards paid <= accrued share

```
cd poc && forge test --match-contract IncorrectRewardAccounting -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/IncorrectRewardAccounting.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/incorrect-reward-accounting.md)

---

## unverified-flashloan-callback
{: #unverified-flashloan-callback }

**Class** SC05/SC01 · **Chains** evm · **Status** `coded`

A callback that the protocol calls back into (onFlashLoan / executeOperation / receiveFlashLoan / uniswapV2Call / uniswapV3SwapCallback / pancakeCall / tokensReceived) performs privileged logic but never checks msg.sender == the genuine lender/pool, nor (for flash loans) initiator == address(this). An attacker calls it directly with fabricated args and triggers the privileged path with no real loan. Fix: authenticate caller + initiator.

**Invariant:** a privileged callback can be entered only via the genuine protocol mid-operation (trusted msg.sender, self-initiated)

```
cd poc && forge test --match-contract UnverifiedCallback -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/UnverifiedCallback.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/unverified-flashloan-callback.md)

---

## bridge-deposit-no-code-token
{: #bridge-deposit-no-code-token }

**Class** SC02 · **Chains** evm · **Status** `coded` · **Loss** $80,000,000

A bridge deposit takes an arbitrary token address and credits the bridged balance based on a low-level transferFrom call's success flag. A call to a codeless address returns (true, "") with no tokens moved, so an attacker deposits a no-code/zero token and is credited the full amount (Qubit qBridge, ~$80M). Fix: allow-list the token, require code.length > 0, and credit a measured balance delta.

**Invariant:** a deposit is credited only after real tokens of a known/allow-listed, code-bearing asset have actually arrived

```
cd poc && forge test --match-contract BridgeNoCodeToken -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/BridgeNoCodeToken.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/bridge-deposit-no-code-token-2022-01.md)

---

## first-deposit-amm-skim
{: #first-deposit-amm-skim }

**Class** SC07 · **Chains** evm · **Status** `coded`

A UniV2-style pair with no MINIMUM_LIQUIDITY lock lets the first LP mint 1 LP, donate tokens directly to inflate the value of that unit, and a later LP's min() round-down mints zero LP while their deposit is absorbed; the first LP (100% of supply) redeems the whole pool. The AMM-LP variant of the inflation attack. Fix: burn MINIMUM_LIQUIDITY on first mint + require liquidity > 0.

**Invariant:** a later provider's minted LP reflects their fair share; no first-depositor donation drives a subsequent mint to zero

```
cd poc && forge test --match-contract FirstDepositSkim -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/FirstDepositSkim.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/first-deposit-amm-skim.md)

---

## cei-reentrancy
{: #cei-reentrancy }

**Class** SC08 · **Chains** evm · **Status** `coded`

A state-changing function makes an external call (ETH send, ERC777/721 hook, arbitrary callback) BEFORE finalizing its own state, so a malicious callback re-enters while the state still reads its pre-call value and drains the contract. The classic CEI-violation reentrancy (The DAO, Lendf.me, Fei/Rari); the state-changing sibling of read-only-reentrancy.

**Invariant:** all state/effects are finalized before any external call; sum(balances) == contract balance across every call

```
cd poc && forge test --match-contract CeiReentrancy -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/CeiReentrancy.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/cei-reentrancy.md) · [fork replay](https://github.com/novaondesk/aegis/blob/main/ethernaut/test/Reentrance.t.sol)

---

## meta-tx-msgsender-spoof
{: #meta-tx-msgsender-spoof }

**Class** SC01 · **Chains** evm · **Status** `coded`

A target derives the logical caller from forwarder-appended calldata (ERC-2771 `_msgSender()` reads the trailing 20 bytes). A forwarder that relays an arbitrary `from` without an EIP-712 signature + nonce from `from` lets an attacker act as any victim, bypassing every `_msgSender()`-based authorization. Surfaced by DVD v4 Naive Receiver. Fix: restrict the forwarder set and verify a signed, nonced request.

**Invariant:** no forwarder call can change balances[X]/privileges of X unless X signed the request (or is msg.sender)

```
cd poc && forge test --match-contract MetaTxMsgSenderSpoof -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/MetaTxMsgSenderSpoof.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/meta-tx-msgsender-spoof.md)

---

## calldata-abi-smuggling
{: #calldata-abi-smuggling }

**Class** SC05/SC01 · **Chains** evm · **Status** `coded`

A gatekeeper reads the guarded selector from a fixed calldata offset (assuming canonical ABI encoding) but forwards a dynamic `bytes` param whose offset the attacker controls — so an allowed selector passes the check while `sweepFunds` actually runs. DVD v4 ABI Smuggling; Ethernaut Switch/HigherOrder. Fix: validate the selector of the exact bytes you dispatch (`actionData[:4]`).

**Invariant:** the function authorized by the guard == the function executed, for every crafted calldata layout

```
cd poc && forge test --match-contract CalldataAbiSmuggling -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/CalldataAbiSmuggling.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/calldata-abi-smuggling.md)

---

## forced-ether-balance-assumption
{: #forced-ether-balance-assumption }

**Class** SC02 · **Chains** evm · **Status** `coded`

Logic that treats `address(this).balance` as if it changes only through its own payable entrypoints is wrong: `selfdestruct(target)` forces ETH into any account, and counterfactual addresses can be pre-funded. A strict-equality or threshold check on the raw balance can be bricked (DoS) or triggered early by one forced wei. Ethernaut Force/King. Fix: gate on internal accounting, use `>=`, sweep surplus.

**Invariant:** control flow depends only on values the contract authoritatively tracks; forced ether cannot change reachability

```
cd poc && forge test --match-contract ForcedEtherBalanceAssumption -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/ForcedEtherBalanceAssumption.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/forced-ether-balance-assumption.md)

---

## dos-griefing-revert
{: #dos-griefing-revert }

**Class** SC10/SC02 · **Chains** evm · **Status** `coded`

A flow that pushes ETH/tokens to an externally chosen address and requires the send to succeed hands that recipient a veto: a contract with a reverting `receive` freezes the whole path for everyone (also: unbounded loops over a user-growable list). Ethernaut King/Denial. Fix: pull-payment ledger + per-recipient failure isolation; bound or chunk loops.

**Invariant:** one participant's failure (revert / gas / list size) cannot block another participant's progress

```
cd poc && forge test --match-contract DosGriefingRevert -vv
```
[PoC test](https://github.com/novaondesk/aegis/blob/main/poc/test/DosGriefingRevert.t.sol) · [case study](https://github.com/novaondesk/aegis/blob/main/docs/exploits/dos-griefing-revert.md)

---
