# Solodit / Cyfrin Aggregated Audit Checklist (mined)

> Mined 2026-06-01 from `github.com/Cyfrin/audit-checklist` (`checklist.json`).
> Community-curated, battle-tested superset of audit checks (each has ID, question,
> remediation, references in the source JSON). Use as the exhaustive REVIEW backstop;
> `master-checklist.md` is our curated, exploit-justified front-line subset.

> **370 leaf check items** across 13 top categories.

## Attacker's Mindset

### Denial-Of-Service(DOS) Attack
- [ ] `SOL-AM-DOSA-1` Is the withdrawal pattern followed to prevent denial of service?
- [ ] `SOL-AM-DOSA-2` Is there a minimum transaction amount enforced?
- [ ] `SOL-AM-DOSA-3` How does the protocol handle tokens with blacklisting functionality?
- [ ] `SOL-AM-DOSA-4` Can forcing the protocol to process a queue lead to DOS?
- [ ] `SOL-AM-DOSA-5` What happens with low decimal tokens that might cause DOS?
- [ ] `SOL-AM-DOSA-6` Does the protocol handle external contract interactions safely?

### Donation Attack
- [ ] `SOL-AM-DA-1` Does the protocol rely on `balance` or `balanceOf` instead of internal accounting?

### Front-running Attack
- [ ] `SOL-AM-FrA-1` Are "get-or-create" patterns protected against front-running attacks?
- [ ] `SOL-AM-FrA-2` Are two-transaction actions designed to be safe from frontrunning?
- [ ] `SOL-AM-FrA-3` Can users maliciously cause others' transactions to revert by preempting with dust?
- [ ] `SOL-AM-FrA-4` Is the protocol using a properly user-bound commit-reveal scheme?

### Griefing Attack
- [ ] `SOL-AM-GA-1` Is there an external function that relies on states that can be changed by others?
- [ ] `SOL-AM-GA-2` Can the contract operations be manipulated with precise gas limit specifications?

### Miner Attack
- [ ] `SOL-AM-MA-1` Is block.timestamp used for time-sensitive operations?
- [ ] `SOL-AM-MA-2` Is the contract using block properties like timestamp or difficulty for randomness generation?
- [ ] `SOL-AM-MA-3` Is contract logic sensitive to transaction ordering?

### Price Manipulation Attack
- [ ] `SOL-AM-PMA-1` Is the price calculated by the ratio of token balances?
- [ ] `SOL-AM-PMA-2` Is the price calculated from DEX liquidity pool spot prices?

### Reentrancy Attack
- [ ] `SOL-AM-ReentrancyAttack-1` Is there a view function that can return a stale value during interactions?
- [ ] `SOL-AM-ReentrancyAttack-2` Is there any state change after interaction to an external contract?

### Replay Attack
- [ ] `SOL-AM-ReplayAttack-1` Are there protections against replay attacks for failed transactions?
- [ ] `SOL-AM-ReplayAttack-2` Is there protection against replaying signatures on different chains?

### Rug Pull
- [ ] `SOL-AM-RP-1` Can the admin of the protocol pull assets from the protocol?

### Sandwich Attack
- [ ] `SOL-AM-SandwichAttack-1` Does the protocol have an explicit slippage protection on user interactions?

### Sybil Attack
- [ ] `SOL-AM-SybilAttack-1` Is there a mechanism depending on the number of users?

## Basics

### Access Control
- [ ] `SOL-Basics-AC-1` Did you clarify all the actors and their allowed interactions in the protocol?
- [ ] `SOL-Basics-AC-2` Are there functions lacking proper access controls?
- [ ] `SOL-Basics-AC-3` Do certain addresses require whitelisting?
- [ ] `SOL-Basics-AC-4` Does the protocol allow transfer of privileges?
- [ ] `SOL-Basics-AC-5` What happens during the transfer of privileges?
- [ ] `SOL-Basics-AC-6` Does the contract inherit others?
- [ ] `SOL-Basics-AC-7` Does the contract use `tx.origin` in validation?

### Array / Loop
- [ ] `SOL-Basics-AL-1` What happens on the first and the last cycle of the iteration?
- [ ] `SOL-Basics-AL-4` How does the protocol remove an item from an array?
- [ ] `SOL-Basics-AL-5` Does any function get an index of an array as an argument?
- [ ] `SOL-Basics-AL-6` Is the summing of variables done accurately compared to separate calculations?
- [ ] `SOL-Basics-AL-7` Is it fine to have duplicate items in the array?
- [ ] `SOL-Basics-AL-8` Is there any issue with the first and the last iteration?
- [ ] `SOL-Basics-AL-9` Is there possibility of iteration of a huge array?
- [ ] `SOL-Basics-AL-10` Is there a potential for a Denial-of-Service (DoS) attack in the loop?
- [ ] `SOL-Basics-AL-11` Is `msg.value` used within a loop?
- [ ] `SOL-Basics-AL-12` Is there a loop to handle batch fund transfer?
- [ ] `SOL-Basics-AL-13` Is there a break or continue inside a loop?

### Block Reorganization
- [ ] `SOL-Basics-BR-1` Does the protocol implement a factory pattern using the CREATE opcode?

### Event
- [ ] `SOL-Basics-Event-1` Does the protocol emit events on important state changes?

### Function
- [ ] `SOL-Basics-Function-1` Are the inputs validated?
- [ ] `SOL-Basics-Function-2` Are the outputs validated?
- [ ] `SOL-Basics-Function-3` Can the function be front-run?
- [ ] `SOL-Basics-Function-4` Are the code comments coherent with the implementation?
- [ ] `SOL-Basics-Function-5` Can edge case inputs (0, max) result in unexpected behavior?
- [ ] `SOL-Basics-Function-6` Does the function allow arbitrary user input?
- [ ] `SOL-Basics-Function-7` Should it be `external`/`public`?
- [ ] `SOL-Basics-Function-8` Does this function need to be called by only EOA or only contracts?
- [ ] `SOL-Basics-Function-9` Does this function need to be restricted for specific callers?

### Inheritance
- [ ] `SOL-Basics-Inheritance-1` Is it necessary to limit visibility of parent contract's public functions?
- [ ] `SOL-Basics-Inheritance-2` Were all necessary functions implemented to fulfill inheritance purpose?
- [ ] `SOL-Basics-Inheritance-3` Has the contract implemented an interface?
- [ ] `SOL-Basics-Inheritance-4` Does the inheritance order matter?

### Initialization
- [ ] `SOL-Basics-Initialization-1` Are important state variables initialized properly?
- [ ] `SOL-Basics-Initialization-2` Has the contract inherited OpenZeppelin's Initializable?
- [ ] `SOL-Basics-Initialization-3` Does the contract have a separate initializer function other than a constructor?

### Map
- [ ] `SOL-Basics-Map-1` Is there need to delete the existing item from a map?

### Math
- [ ] `SOL-Basics-Math-1` Is the mathematical calculation accurate?
- [ ] `SOL-Basics-Math-2` Is there any loss of precision in time calculations?
- [ ] `SOL-Basics-Math-3` Are you aware that expressions like `1 day` are cast to `uint24`, potentially causing overflows?
- [ ] `SOL-Basics-Math-4` Is there any case where dividing is done before multiplication?
- [ ] `SOL-Basics-Math-5` Does the rounding direction matter?
- [ ] `SOL-Basics-Math-6` Is there a possibility of division by zero?
- [ ] `SOL-Basics-Math-7` Even in versions like `>0.8.0`, have you ensured variables won't underflow or overflow leading to reverts?
- [ ] `SOL-Basics-Math-8` Are you aware that assigning a negative value to an unsigned integer causes a revert?
- [ ] `SOL-Basics-Math-9` Have you properly reviewed all usages of `unchecked{}`?
- [ ] `SOL-Basics-Math-10` In comparisons using < or >, should you instead be using ≤ or ≥?
- [ ] `SOL-Basics-Math-11` Have you taken into consideration mathematical operations in inline assembly?
- [ ] `SOL-Basics-Math-12` What happens for the minimum/maximum values included in the calculation?

### Payment
- [ ] `SOL-Basics-Payment-1` Is it possible for the receiver to revert?
- [ ] `SOL-Basics-Payment-2` Does the function gets the payment amount as a parameter?
- [ ] `SOL-Basics-Payment-3` Are there vulnerabilities related to force-feeding?
- [ ] `SOL-Basics-Payment-4` What is the minimum deposit/withdrawal amount?
- [ ] `SOL-Basics-Payment-5` How is the withdrawal handled?
- [ ] `SOL-Basics-Payment-6` Is `transfer()` or `send()` used for sending ETH?
- [ ] `SOL-Basics-Payment-7` Is it possible for native ETH to be locked in the contract?

### Proxy/Upgradable
- [ ] `SOL-Basics-PU-1` Is there a constructor in the proxied contract?
- [ ] `SOL-Basics-PU-2` Is the `initializer` modifier applied to the `initialization()` function?
- [ ] `SOL-Basics-PU-3` Is the upgradable version used for initialization?
- [ ] `SOL-Basics-PU-4` Is the `authorizeUpgrade()` function properly secured in a UUPS setup?
- [ ] `SOL-Basics-PU-5` Is the contract initialized?
- [ ] `SOL-Basics-PU-6` Are `selfdestruct` and `delegatecall` used within the implementation contracts?
- [ ] `SOL-Basics-PU-7` Are values in immutable variables preserved between upgrades?
- [ ] `SOL-Basics-PU-8` Has the contract inherited the correct branch of OpenZeppelin library?
- [ ] `SOL-Basics-PU-9` Could an upgrade of the contract result in storage collision?
- [ ] `SOL-Basics-PU-10` Are the order and types of storage variables consistent between upgrades?

### Type
- [ ] `SOL-Basics-Type-1` Is there a forced type casting?
- [ ] `SOL-Basics-Type-2` Does the protocol use time units like `days`?

### Version Issues

#### EIP Adoption Issues
- [ ] `SOL-Basics-VI-EAI-1` EIP-4758: Does the contract use `selfdestruct()`?

#### OpenZeppelin Version Issues
- [ ] `SOL-Basics-VI-OVI-1` Does the contract use `ERC2771Context`? (version >=4.0.0 <4.9.3)
- [ ] `SOL-Basics-VI-OVI-2` Does the contract use OpenZeppelin's GovernorCompatibilityBravo? (version >=4.3.0 <4.8.3)
- [ ] `SOL-Basics-VI-OVI-3` Does the contract use OpenZeppelin's ECDSA.recover or ECDSA.tryRecover? (version <4.7.3)
- [ ] `SOL-Basics-VI-OVI-4` Does the contract use OpenZeppelin's ERC777? (version <3.4.0-rc.0)
- [ ] `SOL-Basics-VI-OVI-5` Does the contract use OpenZeppelin's `MerkleProof`? (version >=4.7.0 <4.9.2)
- [ ] `SOL-Basics-VI-OVI-6` Does the contract use OpenZeppelin's Governor or GovernorCompatibilityBravo? (version >=4.3.0 <4.9.1)
- [ ] `SOL-Basics-VI-OVI-7` Does the contract use OpenZeppelin's TransparentUpgradeableProxy? (version >=3.2.0 <4.8.3)
- [ ] `SOL-Basics-VI-OVI-8` Does the contract use OpenZeppelin's ERC721Consecutive?(version >=4.8.0 <4.8.2)
- [ ] `SOL-Basics-VI-OVI-9` Does the contract use OpenZeppelin's ERC165Checker or ERC165CheckerUpgradeable? (version >=2.3.0 <4.7.2)
- [ ] `SOL-Basics-VI-OVI-10` Does the contract use OpenZeppelin's LibArbitrumL2 or CrossChainEnabledArbitrumL2? (version >=4.6.0 <4.7.2)
- [ ] `SOL-Basics-VI-OVI-11` Does the contract use OpenZeppelin's GovernorVotesQuorumFraction? (version >=4.3.0 <4.7.2)
- [ ] `SOL-Basics-VI-OVI-12` Does the contract use OpenZeppelin's SignatureChecker? (version >=4.1.0 <4.7.1)
- [ ] `SOL-Basics-VI-OVI-13` Does the contract use OpenZeppelin's ERC165Checker? (version >=4.0.0 <4.7.1)
- [ ] `SOL-Basics-VI-OVI-14` Does the contract use OpenZeppelin's GovernorCompatibilityBravo? (version >=4.3.0 <4.4.2)
- [ ] `SOL-Basics-VI-OVI-15` Does the contract use OpenZeppelin's Initializable? (version >=3.2.0 <4.4.1)
- [ ] `SOL-Basics-VI-OVI-16` Does the contract use OpenZeppelin's ERC1155? (version >=4.2.0 <4.3.3)
- [ ] `SOL-Basics-VI-OVI-17` Does the contract use OpenZeppelin's UUPSUpgradeable? (version >=4.1.0 <4.3.2)
- [ ] `SOL-Basics-VI-OVI-18` Does the contract use OpenZeppelin's TimelockController? (version >=4.0.0-beta.0 <4.3.1\\n<3.4.2)

#### Solidity Version Issues
- [ ] `SOL-Basics-VI-SVI-1` Does the contract encode storage structs or arrays with types under 32 bytes directly using experimental ABIEncoderV2? (version 0.5.0~0.5.6)
- [ ] `SOL-Basics-VI-SVI-2` Are there any instances where empty strings are directly passed to function calls? (version ~0.4.11)
- [ ] `SOL-Basics-VI-SVI-3` Does the optimizer replace specific constants with alternative computations? (version ~0.4.10)
- [ ] `SOL-Basics-VI-SVI-4` Does the contract use `abi.encodePacked`, especially in hash generation? (version >= 0.8.17)
- [ ] `SOL-Basics-VI-SVI-5` BUILD: Is the contract optimized using sequences containing FullInliner with non-expression-split code? (version 0.6.7~0.8.20)
- [ ] `SOL-Basics-VI-SVI-6` Are there any functions that conditionally terminate inside an inline assembly? (version 0.8.13~0.8.16)
- [ ] `SOL-Basics-VI-SVI-7` Are tuples containing a statically-sized calldata array at the end being ABI-encoded? (version 0.5.8~0.8.15)
- [ ] `SOL-Basics-VI-SVI-8` Does the contract have functions that copy `bytes` arrays from memory or calldata directly to storage? (version 0.0.1~0.8.14)
- [ ] `SOL-Basics-VI-SVI-9` Is there a function with multiple inline assembly blocks? (version 0.8.13~0.8.14)
- [ ] `SOL-Basics-VI-SVI-10` Is a nested array being ABI-encoded or passed directly to an external function? (version 0.5.8~0.8.13)
- [ ] `SOL-Basics-VI-SVI-11` Is `abi.encodeCall` used together with fixed-length bytes literals? (version 0.8.11~0.8.12)
- [ ] `SOL-Basics-VI-SVI-12` Is there any user defined types based on types shorter than 32 bytes? (version =0.8.8)
- [ ] `SOL-Basics-VI-SVI-13` Is there an immutable variable of signed integer type shorter than 256 bits? (version 0.6.5~0.8.8)
- [ ] `SOL-Basics-VI-SVI-14` Is there any use of `abi.encode` on memory with multi-dimensional array or structs? (version 0.4.16~0.8.3)
- [ ] `SOL-Basics-VI-SVI-15` Is there an inline assembly block with `keccak256` inside? (version ~0.8.2)
- [ ] `SOL-Basics-VI-SVI-16` Is there a copy of an empty `bytes` or `string` from `memory` or `calldata` to `storage`? (version ~0.7.3)
- [ ] `SOL-Basics-VI-SVI-17` Is there a dynamically-sized storage-array with types of size at most 16 bytes? (version ~0.7.2)
- [ ] `SOL-Basics-VI-SVI-18` Does the library use contract types in events? (version 0.5.0~0.5.7)
- [ ] `SOL-Basics-VI-SVI-19` Does the contract use internal library functions with calldata parameters via `using for`? (version =0.6.9)
- [ ] `SOL-Basics-VI-SVI-20` Are string literals with double backslashes passed directly to external or encoding functions with ABIEncoderV2 enabled? (version 0.5.14~0.6.7)
- [ ] `SOL-Basics-VI-SVI-21` Does the contract access slices of dynamic arrays, especially multi-dimensional ones? (version 0.6.0~0.6.7)
- [ ] `SOL-Basics-VI-SVI-22` Is there a contract with creation code, no constructor, but a base with a constructor that accepts non-zero values? (version 0.4.5~0.6.7)
- [ ] `SOL-Basics-VI-SVI-23` Does the contract create extremely large memory arrays? (version 0.2.0~0.6.4)
- [ ] `SOL-Basics-VI-SVI-24` Does the contract's inline assembly with Yul optimizer use assignments inside for loops combined with continue or break? (version =0.6.0)
- [ ] `SOL-Basics-VI-SVI-25` Does the contract allow private methods to be overridden by inheriting contracts? (version 0.3.0~0.5.16)
- [ ] `SOL-Basics-VI-SVI-26` Is there any Yul's continue or break statement inside the loop?? (version 0.5.8~0.5.15)
- [ ] `SOL-Basics-VI-SVI-27` Are both experimental ABIEncoderV2 and Yul optimizer activated? (version =0.5.14)
- [ ] `SOL-Basics-VI-SVI-28` Does the contract read from calldata structs with dynamic yet statically-sized members? (version 0.5.6~0.5.10)
- [ ] `SOL-Basics-VI-SVI-29` Does the contract assign arrays of signed integers to differently typed storage arrays? (version 0.4.7~0.5.9)
- [ ] `SOL-Basics-VI-SVI-30` Does the contract directly encode storage arrays with structs or static arrays in external calls or abi.encode*? (version 0.4.16~0.5.9)
- [ ] `SOL-Basics-VI-SVI-31` Does the contract's constructor accept structs or arrays with dynamic arrays? (version 0.4.16~0.5.8)
- [ ] `SOL-Basics-VI-SVI-32` Are uninitialized internal function pointers created in the constructor being called? (version 0.5.0~0.5.7)
- [ ] `SOL-Basics-VI-SVI-33` Are uninitialized internal function pointers created in the constructor being called? (version 0.4.5~0.4.25)
- [ ] `SOL-Basics-VI-SVI-34` Does the library use contract types in events? (version 0.3.0~0.4.25)
- [ ] `SOL-Basics-VI-SVI-35` Does the contract encode storage structs or arrays with types under 32 bytes directly using experimental ABIEncoderV2? (version 0.4.19~0.4.25)
- [ ] `SOL-Basics-VI-SVI-36` Does the contract's optimizer handle byte opcodes with a second argument of 31 or an equivalent constant expression? (version 0.5.5~0.5.6)
- [ ] `SOL-Basics-VI-SVI-37` Are there double bitwise shifts with large constants that might sum up to overflow 256 bits? (version =0.5.5)
- [ ] `SOL-Basics-VI-SVI-38` Is the ** operator used with an exponent type shorter than 256 bits? (version ~0.4.24)
- [ ] `SOL-Basics-VI-SVI-39` Are structs used in the logged events? (version 0.4.17~0.4.24)
- [ ] `SOL-Basics-VI-SVI-40` Are functions returning multi-dimensional fixed-size arrays called? (version 0.1.4~0.4.21)
- [ ] `SOL-Basics-VI-SVI-41` Does the contract use both new-style and old-style constructors simultaneously? (version =0.4.22)
- [ ] `SOL-Basics-VI-SVI-42` Is there a function name crafted to potentially override the fallback function execution? (version ~0.4.17)
- [ ] `SOL-Basics-VI-SVI-43` Is the low-level .delegatecall() used without checking the actual execution outcome? (version 0.3.0~0.4.14)
- [ ] `SOL-Basics-VI-SVI-44` Is the ecrecover() function used without validating its input? (version ~0.4.13)
- [ ] `SOL-Basics-VI-SVI-45` Is the `.selector` member accessed on complex expressions? (version 0.6.2~0.8.20)
- [ ] `SOL-Basics-VI-SVI-46` Is there any inconsistency (`memory` vs `calldata`) in the param type during inheritance? (version 0.6.9~0.8.13)
- [ ] `SOL-Basics-VI-SVI-47` Are there any functions with the same name and parameter type inside the same contract? (version =0.7.1)
- [ ] `SOL-Basics-VI-SVI-48` Does the contract use tuple assignments with multi-stack-slot components, like nested tuples or dynamic calldata references? (version 0.1.6~0.6.5)

## Centralization Risk
- [ ] `SOL-CR-1` What happens to the user accounting in special conditions?
- [ ] `SOL-CR-2` Is there a pause mechanism?
- [ ] `SOL-CR-3` Is there a functionality for the admin to withdraw from the protocol?
- [ ] `SOL-CR-4` Can the admin change critical protocol property immediately?
- [ ] `SOL-CR-5` Is there any admin setter function missing events?
- [ ] `SOL-CR-6` How is the ownership/privilege transferred??
- [ ] `SOL-CR-7` Is there a proper validation in privileged setter functions?

## Defi

### AMM/Swap
- [ ] `SOL-Defi-AS-1` Is hardcoded slippage used?
- [ ] `SOL-Defi-AS-2` Is there a deadline protection?
- [ ] `SOL-Defi-AS-3` Is there a validation check for protocol reserves?
- [ ] `SOL-Defi-AS-4` Does the AMM utilize forked code?
- [ ] `SOL-Defi-AS-5` Are there rounding issues in product constant formulas?
- [ ] `SOL-Defi-AS-6` Can arbitrary calls be made from user input?
- [ ] `SOL-Defi-AS-7` Is there a mechanism in place to protect against excessive slippage?
- [ ] `SOL-Defi-AS-8` Does the AMM properly handle tokens of varying decimal configurations and token types?
- [ ] `SOL-Defi-AS-9` Does the AMM support the fee-on-transfer tokens?
- [ ] `SOL-Defi-AS-10` Does the AMM support the rebasing tokens?
- [ ] `SOL-Defi-AS-11` Does the protocol calculate `minAmountOut` before a token swap?
- [ ] `SOL-Defi-AS-12` Does the integrating contract verify the caller address in its callback functions?
- [ ] `SOL-Defi-AS-13` Is the slippage calculated on-chain?
- [ ] `SOL-Defi-AS-14` Is the slippage parameter enforced at the last step before transferring funds to users?

### FlashLoan
- [ ] `SOL-Defi-FlashLoan-1` Is withdraw disabled in the same block to prevent flashloan attacks?
- [ ] `SOL-Defi-FlashLoan-2` Can ERC4626 be manipulated through flashloans?

### General
- [ ] `SOL-Defi-General-1` Can the protocol handle ERC20 tokens with decimals other than 18?
- [ ] `SOL-Defi-General-2` Are there unexpected rewards accruing for user deposited assets?
- [ ] `SOL-Defi-General-3` Could direct transfers of funds introduce vulnerabilities?
- [ ] `SOL-Defi-General-4` Could the initial deposit introduce any issues?
- [ ] `SOL-Defi-General-5` Are the protocol token pegged to any other asset?
- [ ] `SOL-Defi-General-6` Does the protocol revert on maximum approval to prevent over-allowance?
- [ ] `SOL-Defi-General-7` What would happen if only 1 wei remains in the pool?
- [ ] `SOL-Defi-General-8` Is it possible to withdraw in the same transaction of deposit?
- [ ] `SOL-Defi-General-9` Does the protocol aim to support ALL kinds of ERC20 tokens?

### Lending
- [ ] `SOL-Defi-Lending-1` Will the liquidation process function effectively during rapid market downturns?
- [ ] `SOL-Defi-Lending-2` Can a position be liquidated if the loan remains unpaid or if the collateral falls below the required threshold?
- [ ] `SOL-Defi-Lending-3` Is it possible for a user to gain undue profit from self-liquidation?
- [ ] `SOL-Defi-Lending-4` If token transfers or collateral additions are temporarily paused, can a user still be liquidated, even if they intend to deposit more funds?
- [ ] `SOL-Defi-Lending-5` If liquidations are temporarily suspended, what are the implications when they are resumed?
- [ ] `SOL-Defi-Lending-6` Is it possible for users to manipulate the system by front-running and slightly increasing their collateral to prevent liquidations?
- [ ] `SOL-Defi-Lending-7` Are all positions, regardless of size, incentivized adequately for liquidation?
- [ ] `SOL-Defi-Lending-8` Is interest considered during Loan-to-Value (LTV) calculation?
- [ ] `SOL-Defi-Lending-9` Can liquidation and repaying be enabled or disabled simultaneously?
- [ ] `SOL-Defi-Lending-10` Is it possible to lend and borrow the same token within a single transaction?
- [ ] `SOL-Defi-Lending-11` Is there a scenario where a liquidator might receive a lesser amount than anticipated?
- [ ] `SOL-Defi-Lending-12` Is it possible for a user to be in a condition where they cannot repay their loan?

### Liquid Staking Derivatives
- [ ] `SOL-Defi-LSD-1` Can a malicious validator front-run setting withdrawal credentials?
- [ ] `SOL-Defi-LSD-2` Can the exchange rate repricing update be sandwich attacked to drain ETH from the protocol?
- [ ] `SOL-Defi-LSD-3` Can re-entrancy when ETH is sent during rewards/withdrawals or when NFTs are minted via `_safeMint` (to represent pending withdrawals) be used to drain the protocol's ETH?
- [ ] `SOL-Defi-LSD-4` Can an arbitrary exchange rate be set when processing queued withdrawals?
- [ ] `SOL-Defi-LSD-5` Can paused states be bypassed to perform restricted actions even when they should be paused?
- [ ] `SOL-Defi-LSD-6` Can inter-related storage be corrupted, especially storage related to operators and validators?
- [ ] `SOL-Defi-LSD-7` Does the protocol iterate over the entire set of operators or validators?
- [ ] `SOL-Defi-LSD-8` If using a Proof Of Reserves Oracle, does the protocol check for stale data?
- [ ] `SOL-Defi-LSD-9` Does unnecessary precision loss occur in deposit, withdrawal or reward calculations?

### Oracle
- [ ] `SOL-Defi-Oracle-1` Is the Oracle using deprecated Chainlink functions?
- [ ] `SOL-Defi-Oracle-2` Is the returned price validated to be non-zero?
- [ ] `SOL-Defi-Oracle-3` Is the price update time validated?
- [ ] `SOL-Defi-Oracle-4` Is there a validation to check if the rollup sequencer is running?
- [ ] `SOL-Defi-Oracle-5` Is the Oracle's TWAP period appropriately set?
- [ ] `SOL-Defi-Oracle-6` Is the desired price feed pair supported across all deployed chains?
- [ ] `SOL-Defi-Oracle-7` Is the heartbeat of the price feed suitable for the use case?
- [ ] `SOL-Defi-Oracle-8` Are there any inconsistencies with decimal precision when using different price feeds?
- [ ] `SOL-Defi-Oracle-9` Is the price feed address hard-coded?
- [ ] `SOL-Defi-Oracle-10` What happens if oracle price updates are front-run?
- [ ] `SOL-Defi-Oracle-11` How does the system handle potential oracle reverts?
- [ ] `SOL-Defi-Oracle-12` Are the price feeds appropriate for the underlying assets?
- [ ] `SOL-Defi-Oracle-13` Is the contract vulnerable to oracle manipulation, especially using spot prices from AMMs?
- [ ] `SOL-Defi-Oracle-14` How does the system address potential inaccuracies during flash crashes?

### Staking
- [ ] `SOL-Defi-Staking-1` Can a user amplify another user's time lock duration by stacking tokens on their behalf?
- [ ] `SOL-Defi-Staking-2` Can the distribution of rewards be unduly delayed or prematurely claimed?
- [ ] `SOL-Defi-Staking-3` Are rewards up-to-date in all use-cases?

## External Call
- [ ] `SOL-EC-1` What are the implications if the call reenters a different function?
- [ ] `SOL-EC-2` Is there a multi-call?
- [ ] `SOL-EC-3` What are the risks associated with using delegatecall in smart contracts?
- [ ] `SOL-EC-4` Is the external contract call necessary?
- [ ] `SOL-EC-5` Has the called address been whitelisted?
- [ ] `SOL-EC-6` Is there suspicion when a fixed gas amount is specified?
- [ ] `SOL-EC-7` What happens if the call consumes all provided gas?
- [ ] `SOL-EC-8` Is the contract passing large data to an unknown address?
- [ ] `SOL-EC-9` What happens if the call returns vast data?
- [ ] `SOL-EC-10` Are there any delegate calls to non-library contracts?
- [ ] `SOL-EC-11` Is there a strict policy against delegate calls to untrusted contracts?
- [ ] `SOL-EC-12` Is the address's existence verified?
- [ ] `SOL-EC-13` Is the check-effect-interaction pattern being utilized?
- [ ] `SOL-EC-14` How is the msg.sender handled?

## Hash / Merkle Tree
- [ ] `SOL-HMT-1` Is the Merkle tree vulnerable to front-running attacks?
- [ ] `SOL-HMT-2` Does the claim method validate `msg.sender`?
- [ ] `SOL-HMT-3` What is the result when passing a zero hash to the Merkle tree functions?
- [ ] `SOL-HMT-4` What occurs if the same proof is duplicated within the Merkle tree?
- [ ] `SOL-HMT-5` Are the leaves of the Merkle tree hashed with the claimable address included?

## Heuristics
- [ ] `SOL-Heuristics-1` Is there any logic implemented multiple times?
- [ ] `SOL-Heuristics-2` Does the contract use any nested structures?
- [ ] `SOL-Heuristics-3` Is there any unexpected behavior when `src==dst` (or `caller==receiver`)?
- [ ] `SOL-Heuristics-4` Is the NonReentrant modifier placed before every other modifier?
- [ ] `SOL-Heuristics-5` Does the `try/catch` block account for potential gas shortages?
- [ ] `SOL-Heuristics-6` Did you check the relevant EIP recommendations and security concerns?
- [ ] `SOL-Heuristics-7` Are there any off-by-one errors?
- [ ] `SOL-Heuristics-8` Are logical operators used correctly?
- [ ] `SOL-Heuristics-9` What happens if the protocol's contracts are inputted as if they are normal actors?
- [ ] `SOL-Heuristics-10` Are there rounding errors that can be amplified?
- [ ] `SOL-Heuristics-11` Is there any uninitialized state?
- [ ] `SOL-Heuristics-12` Can functions be invoked multiple times with identical parameters?
- [ ] `SOL-Heuristics-13` Is the global state updated correctly?
- [ ] `SOL-Heuristics-14` Is ETH/WETH handling implemented correctly?
- [ ] `SOL-Heuristics-15` Does the protocol put any sensitive data on the blockchain?
- [ ] `SOL-Heuristics-16` Are there any code asymmetries?
- [ ] `SOL-Heuristics-17` Does calling a function multiple times with smaller amounts yield the same contract state as calling it once with the aggregate amount?

## Integrations

### AAVE / Compound
- [ ] `SOL-Integrations-AC-1` Does the protocol use cETH token?
- [ ] `SOL-Integrations-AC-2` What happens if the utilization rate is too high, and collateral cannot be retrieved?
- [ ] `SOL-Integrations-AC-3` What happens if the protocol is paused?
- [ ] `SOL-Integrations-AC-4` What happens if the pool becomes deprecated?
- [ ] `SOL-Integrations-AC-5` What happens if assets you lend/borrow are within the same eMode category?
- [ ] `SOL-Integrations-AC-6` Do flash loans on Aave inflate the pool index?
- [ ] `SOL-Integrations-AC-7` Does the protocol properly implement AAVE/COMP reward claims?
- [ ] `SOL-Integrations-AC-8` On AAVE, what happens if a user reaches the maximum debt on an isolated asset?
- [ ] `SOL-Integrations-AC-9` Does borrowing an AAVE siloed asset restrict borrowing other assets?

### Balancer
- [ ] `SOL-Integrations-Balancer-1` Does the protocol use the Balancer's flashloan?
- [ ] `SOL-Integrations-Balancer-2` Does the protocol use Balancer's Oracle? (getTimeWeightedAverage)
- [ ] `SOL-Integrations-Balancer-3` Does the protocol use Balancer's Boosted Pool?
- [ ] `SOL-Integrations-Balancer-4` Does the protocol use Balancer vault pool liquidity status for any pricing?

### Chainlink

#### CCIP
- [ ] `SOL-Integrations-Chainlink-CCIP-1` Does the receiver contract's `_ccipReceive` function properly validate the `sourceChainSelector` and `sender` address against an allowlist?
- [ ] `SOL-Integrations-Chainlink-CCIP-2` Does the sender contract validate the `destinationChainSelector` against an allowlist before calling `ccipSend`?
- [ ] `SOL-Integrations-Chainlink-CCIP-3` Does the receiver contract properly decode data (`any2EvmMessage.data`) ?
- [ ] `SOL-Integrations-Chainlink-CCIP-4` Does the application logic account for the potential latency introduced by waiting for source chain finality as defined by CCIP?
- [ ] `SOL-Integrations-Chainlink-CCIP-5` Are the correct types of token pools (e.g., `BurnMintTokenPool`, `LockReleaseTokenPool`) deployed on the source and destination chains consistent with the desired token handling mechanism?
- [ ] `SOL-Integrations-Chainlink-CCIP-6` Is proper router address verification implemented in the ccipReceive method?
- [ ] `SOL-Integrations-Chainlink-CCIP-7` Are extraArgs parameters hardcoded instead of mutable in cross-chain message configurations?
- [ ] `SOL-Integrations-Chainlink-CCIP-8` Is there a proper failure handling mechanism for CCIP messages to prevent blocking after Smart Execution window expiration?

#### VRF
- [ ] `SOL-Integrations-Chainlink-VRF-1` Are all parameters properly verified when Chainlink VRF is called?
- [ ] `SOL-Integrations-Chainlink-VRF-2` Is it guaranteed that the operator holds sufficient LINK in the subscription?
- [ ] `SOL-Integrations-Chainlink-VRF-3` Is a sufficiently high request confirmation number chosen considering chain re-orgs?
- [ ] `SOL-Integrations-Chainlink-VRF-4` Are measures in place to prevent VRF calls from being frontrun?

### Gnosis Safe
- [ ] `SOL-Integrations-GS-1` Do your modules execute the Guard's hooks?
- [ ] `SOL-Integrations-GS-2` Does the `execTransactionFromModule()` function increment the nonce?

### LayerZero
- [ ] `SOL-Integrations-LayerZero-1` Does the `_debitFrom` function in ONFT properly validate token ownership and transfer permissions?
- [ ] `SOL-Integrations-LayerZero-2` Which type of mechanism are utilized? Blocking or non-blocking?
- [ ] `SOL-Integrations-LayerZero-3` Is gas estimated accurately for cross-chain messages?
- [ ] `SOL-Integrations-LayerZero-4` Is the `_lzSend` function correctly utilized when inheriting LzApp?
- [ ] `SOL-Integrations-LayerZero-5` Is the `ILayerZeroUserApplicationConfig` interface correctly implemented?
- [ ] `SOL-Integrations-LayerZero-6` Are default contracts used?
- [ ] `SOL-Integrations-LayerZero-7` Is the correct number of confirmations chosen for the chain?

### LSD

#### cbETH
- [ ] `SOL-Integrations-LSD-cbETH-1` How is the control over the `cbETH`/`ETH` rate determined? Are there specific addresses with this capability due to the `onlyOracle` modifier?
- [ ] `SOL-Integrations-LSD-cbETH-2` How does the system handle potential decreases in the `cbETH`/`ETH` rate?

#### rETH
- [ ] `SOL-Integrations-LSD-rETH-1` Does the application account for potential penalties or slashes?
- [ ] `SOL-Integrations-LSD-rETH-2` How does the system manage rewards accrued from staking?
- [ ] `SOL-Integrations-LSD-rETH-3` Does the application handle potential reverts in the `burn()` function when there's insufficient ether in the `RocketDepositPool`?
- [ ] `SOL-Integrations-LSD-rETH-4` What measures are in place to counteract potential consensus attacks on RPL nodes?
- [ ] `SOL-Integrations-LSD-rETH-5` How does the system handle the conversion between `ETH` and `rETH`?

#### sfrxETH
- [ ] `SOL-Integrations-LSD-sfrxETH-1` How does the system handle potential detachment of `sfrxETH` from `frxETH` during reward transfers?
- [ ] `SOL-Integrations-LSD-sfrxETH-2` Is the stability of the `sfrxETH`/`ETH` rate guaranteed or can it decrease in the future?

#### stETH
- [ ] `SOL-Integrations-LSD-stETH-1` Is the application aware that `stETH` is a rebasing token?
- [ ] `SOL-Integrations-LSD-stETH-2` Are you aware of the overhead when withdrawing `stETH`/`wstETH`?
- [ ] `SOL-Integrations-LSD-stETH-3` Does the application handle conversions between `stETH` and `wstETH` correctly?

### Uniswap
- [ ] `SOL-Integrations-Uniswap-1` Is the slippage calculated on-chain?
- [ ] `SOL-Integrations-Uniswap-2` Are there refunds after swaps?
- [ ] `SOL-Integrations-Uniswap-3` Is the order of `token0` and `token1` consistent across chains?
- [ ] `SOL-Integrations-Uniswap-4` Are the pools that are being interacted with whitelisted?
- [ ] `SOL-Integrations-Uniswap-5` Is there a reliance on pool reserves?
- [ ] `SOL-Integrations-Uniswap-6` Is `pool.swap()` directly used?
- [ ] `SOL-Integrations-Uniswap-7` Is `unchecked` used properly with Uniswap's math libraries?
- [ ] `SOL-Integrations-Uniswap-8` Is the slippage parameter enforced at the last step before transferring funds to users?
- [ ] `SOL-Integrations-Uniswap-9` Is `pool.slot0` being used to calculate sensitive information like current price and exchange rates?
- [ ] `SOL-Integrations-Uniswap-10` Is a hard-coded fee tier parameter being used?

## Low Level
- [ ] `SOL-LL-1` Is there validation on the size of the input data?
- [ ] `SOL-LL-2` What happens if there is no matching function signature?
- [ ] `SOL-LL-3` Is it checked if the target address of a call has the code?
- [ ] `SOL-LL-4` Is there a check on the return data size when calling precompiled code?
- [ ] `SOL-LL-5` Is there a non-zero check for the denominator?

## Multi-chain/Cross-chain
- [ ] `SOL-McCc-1` Are there assumption of consistency in the `block.number` or `block.timestamp` across chains?
- [ ] `SOL-McCc-2` Has the protocol been checked for the target chain differences?
- [ ] `SOL-McCc-3` Are the EVM opcodes and operations used by the protocol compatible across all targeted chains?
- [ ] `SOL-McCc-4` Does the expected behavior of `tx.origin` and `msg.sender` remain consistent across all deployment chains?
- [ ] `SOL-McCc-5` Is there any possibility of exploiting low gas fees to execute many transactions?
- [ ] `SOL-McCc-6` Is there consistency in ERC20 decimals across chains?
- [ ] `SOL-McCc-7` Have contract upgradability implications been evaluated on different chains?
- [ ] `SOL-McCc-8` Have cross-chain messaging implementations been thoroughly reviewed for permissions and functionality?
- [ ] `SOL-McCc-9` Is there a whitelist of compatible chains?
- [ ] `SOL-McCc-10` Have contracts been checked for compatibility when deployed to the zkSync Era?
- [ ] `SOL-McCc-11` Is block production consistency ensured?
- [ ] `SOL-McCc-12` Is `PUSH0` opcode supported for Solidity version `>=0.8.20`?
- [ ] `SOL-McCc-13` Are there any attributes attached to the bridged assets?

## Signature
- [ ] `SOL-Signature-1` Are signatures guarded against replay attacks?
- [ ] `SOL-Signature-2` Are signatures protected against malleability issues?
- [ ] `SOL-Signature-3` Does the returned public key from the signature verification match the expected public key?
- [ ] `SOL-Signature-4` Is the signature originating from the appropriate entity?
- [ ] `SOL-Signature-5` If the signature has a deadline, is it still valid?

## Timelock
- [ ] `SOL-Timelock-1` Are timelocks implemented for important changes?

## Token

### Fungible : ERC20
- [ ] `SOL-Token-FE-1` Are safe transfer functions used throughout the contract?
- [ ] `SOL-Token-FE-2` Is there potential for a race condition for approvals?
- [ ] `SOL-Token-FE-3` Could a difference in decimals between ERC20 tokens cause issues?
- [ ] `SOL-Token-FE-4` Does the token implement any form of address whitelisting, blacklisting, or checks?
- [ ] `SOL-Token-FE-5` Could the use of multiple addresses for a single token lead to complications?
- [ ] `SOL-Token-FE-6` Does the token charge fee on transfer?
- [ ] `SOL-Token-FE-7` Can the token be ERC777?
- [ ] `SOL-Token-FE-8` Does the protocol use Solmate's `ERC20.safeTransferLib`?
- [ ] `SOL-Token-FE-9` Is there a flash-mint functionality?
- [ ] `SOL-Token-FE-10` What happens on zero amount transfer?
- [ ] `SOL-Token-FE-11` Is the token an ERC2612 implementation?
- [ ] `SOL-Token-FE-12` Can the token be sent to any address?
- [ ] `SOL-Token-FE-13` Is there a direct approval to a non-zero value?
- [ ] `SOL-Token-FE-14` Is there a max approval used?
- [ ] `SOL-Token-FE-15` Can the token be paused?
- [ ] `SOL-Token-FE-16` Is the decrease allowance feature of transferFrom() handled correctly when the sender is the caller?

### Non-fungible : ERC721/1155
- [ ] `SOL-Token-NfE1-1` How are the minting and transfer implemented?
- [ ] `SOL-Token-NfE1-2` Is the contract safe from reentrancy attack?
- [ ] `SOL-Token-NfE1-3` Is the OpenZeppelin implementation of ERC721 and ERC1155 safeguarded against reentrancy attacks, especially in the `safeTransferFrom` functions?
- [ ] `SOL-Token-NfE1-4` Is it possible to steal NFT abusing his approval?
- [ ] `SOL-Token-NfE1-5` Does the ERC721/1155 contract correctly implement supportsInterface?
- [ ] `SOL-Token-NfE1-6` Can the contract support both ERC721 and ERC1155 standards?
- [ ] `SOL-Token-NfE1-7` What happens to the airdrops that are engaged to specific NFT?
- [ ] `SOL-Token-NfE1-8` How is the approval/transfer handled for CryptoPunks collection?
