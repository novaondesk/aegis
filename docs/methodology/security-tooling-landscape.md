# Security Tooling Landscape — what to borrow, and how it makes web3 safer

Survey of existing security tooling — AI pentest agents, AI smart-contract auditors,
recon tooling, and defensive/runtime systems — and concretely how each maps onto **our
suite** and onto **making smart contracts + web3 apps safer**. Sourced; see
`sources.md`. Treat research-paper metrics as claims, not facts.

## Framing: two halves of "safer"
1. **Offense / pre-deployment (our focus):** find the bug before/instead of an attacker.
   Bounty hunting lives here. Tools: static analyzers, fuzzers, AI audit agents, PoC gen.
2. **Defense / runtime:** assume bugs slip through; detect + stop exploitation live.
   Tools: on-chain monitoring, attack detectors, automated circuit-breakers.

A mature web3 app needs both. Our suite is an offense tool, but understanding the
defense layer sharpens target selection (a protocol with auto-pause is a harder, often
lower-payout target than one without).

---

## A. AI pentest agents — cross-domain blueprint

### Shannon (KeygraphHQ/shannon)
Autonomous **web-app/API** pentester. Not smart-contract-specific, but its architecture
is the clearest blueprint for what an "agentic smart-contract hunter" should look like.
- **Multi-agent, 5 sequential phases:** Pre-Recon (source analysis) → Recon (live
  mapping) → Vulnerability Analysis (**5 parallel agents**, one per vuln class) →
  Exploitation (turn hypotheses into real PoCs) → Reporting.
- **"No exploit, no report" policy** — unproven findings are discarded.
- TypeScript; **Claude** for reasoning; **ephemeral Docker** sandboxes; **Temporal**
  for orchestration; multi-LLM backends. White-box, authorized, staging-only.

**Maps to our suite 1:1** — our hunt flow (RECON → TRIAGE → REVIEW → HYPOTHESIS → PROVE
→ REPORT) is the same shape, and Shannon's no-exploit-no-report *is* our "no finding
without a runnable PoC" rule (`AGENTS.md`). **Lessons to adopt:** (1) parallel
specialist agents, one per vuln class, instead of one generalist pass; (2) ephemeral
sandboxed execution for running untrusted target code; (3) durable orchestration so
long scans resume. This is the north star for an eventual `shannon-for-contracts`.

---

## B. AI smart-contract audit agents (the directly-relevant cluster)

### forefy/.context — ⭐ adopt now
"AI Agent Skills for Smart Contract Auditing." **Installs to `.claude/skills/`** and is
auto-invoked by inference — i.e. it runs in *our* exact environment (Claude Code skills).
- Skills: `smart-contract-security-audit` (Solidity, **Anchor**, Vyper, TON, **Sui** —
  covers our whole multi-chain scope), `foundry-poc` (PoC generation), `blockchain-forensics`
  (fund tracing), `sandboxed-audit-runner` (prompt-injection defense on untrusted code),
  `gdocs-audit-report`.
- Format: Agent Skills open standard — `SKILL.md` + progressively-loaded, language-keyed
  reference files + per-language/protocol vulnerability pattern libraries.
- Outputs: triaged findings, code locations, PoCs, **attacker story-flow graphs**.
- Maturity: ~100 stars, established.
- **Action for us:** evaluate installing these skills; our `checklists/` + case studies
  are exactly the kind of pattern library that plugs into a `SKILL.md`. Strong candidate
  to package *our* suite as Agent Skills (see new questions below).

### advaitbd/smartguard — concrete pipeline blueprint
Multi-agent auditor that **generates + runs PoCs**. Input: a file, a directory, or a
**contract address on-chain**.
- Agents: **Analyzer → Skeptic → Exploiter → Generator → Runner** (coordinator-routed).
- Pipeline: Slither static parse → project-context LLM (inter-contract relationships) →
  Analyzer + **RAG over known vuln patterns (Pinecone)** → ExploitRunner executes the
  generated PoC via **`forge test`**.
- **Maps to us:** this is essentially our suite wired into agents — Slither (`tools/slither`)
  + our pattern library as the RAG corpus + Foundry (`poc/`) as the runner. The
  **Skeptic** agent (adversarial false-positive filter) is a pattern worth copying.

### l33tdawg/aether — "AI SC security analysis + PoC generation framework" (to review).

### OpenAuditLabs/agent — multi-agent reference (early-stage, 2★)
Coordinator + Static (Slither) + Dynamic (symbolic/fuzz, Mythril) + ML (Transformer/GNN)
agents; Python/FastAPI, Redis queue, Postgres. AGPL-3.0. Good *architecture* reference
for combining static + dynamic + ML under a coordinator; immature in practice.

### Research-grade (aspirational benchmarks, mostly not OSS)
- **Heimdallr** (arXiv 2601.17833) — neuro-symbolic (Plan-Remind-Solve auditor + **Z3**
  verifier + adversarial filter). *Per the paper:* reproduced **17/20 post-Jun-2025
  exploits ($384M)** and found **4 zero-days on $400M TVL**; identified the **Balancer V2
  $128M "Precision Loss Cascade"** via Z3 math verification. **Key takeaway: the
  arithmetic/precision class (our SC07) is exactly where symbolic verification beats
  pattern-matching** — pair Foundry with **Halmos/Z3** for that class.
- **PoCo** (arXiv 2511.02780) — agentic PoC-exploit generation for contracts.
- **LLM-SmartAudit**, **SmartLLM**, **SPEAR** (multi-agent coordination case study) —
  multi-agent conversational auditing; claim edge on complex logic bugs over classic tools.

---

## C. Recon / analysis tooling (RECON-phase force multipliers)

- **heimdall-rs / heimdall** (Jon-Becker) — advanced EVM toolkit: **decompiles &
  extracts info from UNVERIFIED bytecode**. Huge for on-chain targets with no verified
  source — turns a black-box address into reviewable pseudo-source. **Adopt into RECON.**
- **Knowledge bases to mine:** `sirhashalot/SCV-List` (SCV taxonomy),
  `WeiZ-boot/survey-on-smart-contract-vulnerability` (papers + detection tools),
  `coral-xyz/sealevel-attacks` (Solana — feeds the Anchor checklist).

---

## D. Defensive / runtime mitigation (how live web3 apps get safer)

This is the half that *prevents loss* when a bug exists. Relevant to us mainly for
target selection + understanding what a "good" disclosure recommends.
- **Forta** — decentralized monitoring; **Attack Detector** (heuristics + ML bots),
  **2.0** with BlockSec + Nethermind. Detects exploit patterns in-flight.
- **OpenZeppelin Defender** — monitoring module integrates Forta alerts and can trigger
  **automated response: pause/shutdown** the targeted contract to cut off the attacker.
- **Tenderly** — transaction **simulation**, monitoring, alerting (pre-execution checks).
- Pattern: **monitor → threshold/anomaly → automated circuit-breaker (pause)**. Plus
  transaction-firewall hooks that simulate+screen txs before they land.

**How these make web3 apps safer (and how we'd recommend them in a report):** design
pausability + a monitored circuit-breaker from day one; simulate state-changing txs;
subscribe to an attack-detector; rate-limit/queue large value flows so a single atomic
drain trips a threshold before completing.

---

## E. What this means for OUR suite

**Adopt now (low effort, high value):**
1. Evaluate **forefy/.context** skills in `.claude/skills/` — multi-chain audit + foundry-poc
   already cover our scope; our checklists become its pattern library.
2. Add **heimdall-rs** to the RECON pipeline for unverified on-chain targets.
3. Add **Halmos/Z3 (symbolic)** to the toolbox specifically for the SC07 precision class
   (Heimdallr's edge; complements Foundry fuzzing).

**Build toward (the agentic suite):**
4. A coordinator + parallel **per-class specialist agents** (Shannon/smartguard shape),
   with a **Skeptic** false-positive filter, Slither+semgrep as static feed, our pattern
   library as RAG, and **Foundry as the PoC runner** — gated by no-exploit-no-report.
5. Ephemeral **sandboxed execution** for running untrusted target code safely.

**Don't reinvent:** static (Slither/Mythril/Aderyn), fuzzing (Foundry/Echidna/Medusa),
symbolic (Halmos/Certora) already exist and are best-in-class. Our edge is the
**curated, exploit-derived pattern library + judgment**, orchestrating these — not a new
scanner.

---

## New questions raised (→ backlog)
- Should we **package our suite as Agent Skills** (`SKILL.md`) the way forefy/.context
  does, so any Claude/agent can load our checklists + PoC patterns? (Likely yes.)
- Can we benchmark ourselves against **EVMBench / Heimdallr's 20-exploit set** to measure
  whether the suite + an agent actually reconstructs known exploits?
- Build a **RAG corpus** from `docs/exploits/` + the Solodit 370 + Code4rena reports for
  an Analyzer agent?
- For SC07 specifically: stand up a **Halmos** example alongside the Foundry PoC and
  compare what each catches on the ERC-4626 inflation case.
- Defensive recon: can we **auto-detect whether a target has Forta/Defender auto-pause**
  to factor exploitability + payout realism into target selection?
