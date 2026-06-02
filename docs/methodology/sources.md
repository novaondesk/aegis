# Sources

Secondary reporting used for the v0 research seed. Treat as leads, not facts —
verify technical claims against primary post-mortems and on-chain traces.

## Exploit data / timelines
- CCN — DeFi Hacks 2026: https://www.ccn.com/education/crypto/defi-hacks-exploits-causes-crypto-stolen-2026/
- CCN — $400M+ / Drift, Rhea, Step: https://www.ccn.com/education/crypto/defi-hacks-2026-137m-lost-step-finance-truebit-resolv-exploits/
- Phemex — 2026 bridge exploits: https://phemex.com/blogs/defi-hacks-2026-bridge-exploits-explained
- Bankless — rsETH attack: https://www.bankless.com/trapped-liquidity-7b-bank-run-freezes-cryptos-leadin-lenders-locked-in
- CoinDesk — $292M cross-chain: https://www.coindesk.com/news-analysis/2026/04/19/defi-is-dead-crypto-community-scrambles-after-usd292-million-hack-exposes-cross-chain-risks
- Decrypt — why DeFi keeps losing: https://decrypt.co/368591/why-defi-keeps-losing-millions-to-exploits
- ChainSec — DeFi hacks timeline: https://www.chainsec.io/defi-hacks

## Vulnerability taxonomy
- OWASP Smart Contract Top 10: https://owasp.org/www-project-smart-contract-top-10/
- Hacken — top vulnerabilities w/ real hacks: https://hacken.io/discover/smart-contract-vulnerabilities/
- Coin Bureau — common attacks: https://coinbureau.com/education/most-common-smart-contract-attacks
- Medium (Merbeth) — audited & still broken 2025: https://medium.com/coinmonks/audited-tested-and-still-broken-smart-contract-hacks-of-2025-a76c94e203d1

## Tooling & methodology
- Hacken — auditing tools review 2026: https://hacken.io/discover/audit-tools-review/
- Cyfrin — auditing & security tools: https://www.cyfrin.io/blog/industry-leading-smart-contract-auditing-and-security-tools
- QuillAudits — fuzzing guide 2026: https://www.quillaudits.com/blog/smart-contract/smart-contract-fuzzing
- ChainScore — multi-layer review strategy: https://chainscorelabs.com/en/guides/smart-contract-development/smart-contract-security-audits/how-to-architect-a-multi-layered-security-review-strategy

## Bounty platforms
- Immunefi: https://immunefi.com/bug-bounty/immunefi/information/
- Sherlock — best bounties 2026: https://sherlock.xyz/post/best-web3-bug-bounties-in-2026-the-highest-paying-programs-on-every-platform
- Code4rena shutdown / Immunefi absorb: https://www.theblock.co/post/401179/immufefi-absorb-code4rena-bug-bounty-customers-shutdown-decision
- Best DeFi security practices (repo): https://github.com/arunimshukla/Best-DeFi-Security-Practices

## Security tooling & AI audit agents
- Shannon (AI pentester): https://github.com/KeygraphHQ/shannon
- forefy/.context (AI agent skills for SC auditing): https://github.com/forefy/.context
- advaitbd/smartguard (multi-agent auditor + PoC): https://github.com/advaitbd/smartguard
- l33tdawg/aether (SC security analysis + PoC framework): https://github.com/l33tdawg/aether
- OpenAuditLabs/agent (multi-agent SC analysis engine): https://github.com/OpenAuditLabs/agent
- Heimdallr (neuro-symbolic auditing, arXiv): https://arxiv.org/abs/2601.17833
- PoCo (agentic PoC exploit gen, arXiv): https://arxiv.org/abs/2511.02780
- heimdall-rs (EVM bytecode decompiler): https://github.com/Jon-Becker/heimdall-rs
- sirhashalot/SCV-List (vuln taxonomy): https://github.com/sirhashalot/SCV-List
- WeiZ-boot/survey-on-smart-contract-vulnerability: https://github.com/WeiZ-boot/survey-on-smart-contract-vulnerability
- coral-xyz/sealevel-attacks (Solana): https://github.com/coral-xyz/sealevel-attacks

## Defensive / runtime monitoring
- Forta — preventing exploits with automatic pausing: https://www.forta.org/blog/preventing-smart-contract-exploits-with-automatic-pausing
- Forta — Attack Detector 2.0: https://www.forta.org/blog/attack-detector-2
- Hacken — Web3 security stack: https://hacken.io/discover/web3-security-stack/
- Tenderly — web3 tech stack: https://blog.tenderly.co/web3-tech-stack/

## Solana / Anchor security
- Helius — Hitchhiker's Guide to Solana Program Security: https://www.helius.dev/blog/a-hitchhikers-guide-to-solana-program-security
- Neodyme — Solana Security Workshop: https://neodyme.io/blog/solana-security/
- Anchor Framework Security Best Practices: https://www.anchor-lang.com/docs/security
- Sealevel Attacks (Canonical Examples): https://github.com/coral-xyz/sealevel-attacks
- Nomos — Anchor Framework Security Limits: https://nomoslabs.io/blog/anchor-framework-security-limits-remaining-risks
- VultBase — Anchor Program Security: https://www.vultbase.com/articles/anchor-program-security-solana
- Medium — Solana Security in Anchor V2 Era: https://medium.com/@FrankCastleAudits/solana-security-in-the-anchor-v2-era-where-the-bugs-moved-3050adc39412
- AnchorScan — AnchorLang Security Best Practices 2026: https://anchorscan.ca/blog/anchorlang-security-best-practices-for-2026.html

## Solana exploit case studies (primary sources)
- Loopscale post-mortem (RateX PT pricing, $5.8M): https://blog.loopscale.com/posts/postmortem
- Halborn — Loopscale explained: https://www.halborn.com/blog/post/explained-the-loopscale-hack-april-2025
- Quadriga Initiative — Loopscale case study: https://quadrigainitiative.com/casestudy/loopscale.php
- Nomos — Loopscale full analysis: https://nomoslabs.io/blog/loopscale-hack-oracle-flaw-solana-defi-full-analysis

## Base / OP-Stack L2 security
- OP Stack Docs — Cross-Domain Overview: https://docs.optimism.io/op-stack/bridging/cross-domain
- OP Stack Specs — Messengers: https://specs.optimism.io/protocol/messengers.html
- Chainlink — L2 Sequencer Uptime Feeds: https://docs.chain.link/data-feeds/l2-sequencer-feeds
- Medium — L2 Sequencer and Stale Oracle Prices Bug: https://medium.com/@lopotras/l2-sequencer-and-stale-oracle-prices-bug-54a749417277
- Code4rena — GoodEntry Findings (L2 Sequencer Check): https://github.com/code-423n4/2023-08-goodentry-findings/issues/503
- CryptoHawking — Oracle Manipulation (Stale Chainlink Feeds): https://www.cryptohawking.com/blog/oracle-manipulation-chainlink-staleness
- Chainstack — Base RPC Providers 2026: https://chainstack.com/base-rpc-providers-2026/
- Messari — State of the OP Stack Q1 2026: https://messari.io/report/state-of-the-op-stack-q1-2026

## Exploit recompilation pipeline — primary spine (software-only)

The canonical, reliable sources Onyx mines to recompile past software exploits into
case studies + catalog detectors (see `docs/research-plans/onyx-exploit-recompile.md`).
Scope is **software/code bugs only** — exclude ops, key-compromise, social-engineering,
governance takeover, and supply-chain incidents.

- **DeFiHackLabs (primary)** — 691+ incidents reproduced as runnable Foundry PoCs, one
  per real on-chain hack, each linking the original post-mortem/tx. Chronological
  `past/<YYYY>/` folders; naming `YYYYMMDD_Project---vuln-type`. This is the spine:
  PoC + source already exist, so each entry converts directly into an Aegis case study
  + reusable technique. https://github.com/SunWeb3Sec/DeFiHackLabs
- **DeFiVulnLabs** — distilled common vuln *patterns* as minimal Foundry tests; the
  "reusable technique" reference for generalizing an incident into a detector.
  https://github.com/SunWeb3Sec/DeFiVulnLabs
- **Solodit (Cyfrin)** — aggregated audit-report findings across firms (incl. bugs that
  never became live exploits). Audit-finding dimension; already backs
  `checklists/solodit-aggregated-checklist.md`. https://solodit.cyfrin.io
- **Code4rena report archive** — public contest findings with severity + PoC.
  https://code4rena.com/reports  (org repos: https://github.com/code-423n4)
- **Trail of Bits — not-so-smart-contracts / building-secure-contracts** — annotated
  vulnerable patterns. https://github.com/crytic/building-secure-contracts
- **rekt.news leaderboard** — cross-check losses & timelines. https://rekt.news/leaderboard

Done: [x] Solodit · [x] Code4rena archive · [x] Trail of Bits not-so-smart-contracts
