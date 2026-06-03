// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Silo, IERC20} from "./Silo.sol";

/// Minimal model of Beanstalk's on-chain governance, holding the protocol treasury.
/// A proposal names a `beneficiary` and, on `emergencyCommit`, transfers the ENTIRE
/// treasury to it (modelling `cutBip()` executing a malicious diamond-cut `_init`).
///
/// The only thing that differs between the vulnerable and safe variants is *how voting
/// power is measured* — real-time storage reads vs a snapshot at proposal creation.
/// That single choice is the $181M bug.
abstract contract GovernanceBase {
    Silo public immutable silo;
    IERC20 public immutable treasuryToken;

    uint256 public constant EMERGENCY_PERIOD = 1 days; // C.getGovernanceEmergencyPeriod()
    uint256 public constant THRESHOLD_BPS = 6667; // 2/3 supermajority

    struct Proposal {
        address beneficiary; // where committed funds go (attacker, for the malicious BIP)
        uint256 created; // proposal-creation timestamp == the correct snapshot point
        uint256 snapshotTotalRoots; // total roots in existence at creation
        bool executed;
        mapping(address => bool) votedFor;
        address[] voters;
    }

    Proposal[] internal _proposals;

    constructor(Silo _silo) {
        silo = _silo;
        treasuryToken = _silo.asset();
    }

    /// Pre-submit a proposal (the attacker did this ~24h ahead). Snapshots the total
    /// roots that exist *now* so the safe variant can reject power minted afterwards.
    function propose(address beneficiary) external returns (uint256 bip) {
        bip = _proposals.length;
        Proposal storage p = _proposals.push();
        p.beneficiary = beneficiary;
        p.created = block.timestamp;
        p.snapshotTotalRoots = silo.totalRoots();
    }

    function vote(uint256 bip) external {
        Proposal storage p = _proposals[bip];
        if (!p.votedFor[msg.sender]) {
            p.votedFor[msg.sender] = true;
            p.voters.push(msg.sender);
        }
    }

    /// Voting power measurement — the one line that decides whether the attack works.
    function votePercentBps(uint256 bip) public view virtual returns (uint256);

    function emergencyCommit(uint256 bip) external {
        Proposal storage p = _proposals[bip];
        require(!p.executed, "executed");
        require(block.timestamp >= p.created + EMERGENCY_PERIOD, "too early");
        require(votePercentBps(bip) >= THRESHOLD_BPS, "no supermajority");

        p.executed = true;
        // cutBip(): execute the malicious proposal -> drain the whole treasury.
        treasuryToken.transfer(p.beneficiary, treasuryToken.balanceOf(address(this)));
    }

    function _votersFor(uint256 bip) internal view returns (address[] storage) {
        return _proposals[bip].voters;
    }
}

/// VULNERABLE: `bipVotePercent` reads `rootsFor / totalRoots` from CURRENT storage.
/// Roots minted one block earlier by a flash-loaned deposit count in full.
contract VulnerableGovernance is GovernanceBase {
    constructor(Silo _silo) GovernanceBase(_silo) {}

    function votePercentBps(uint256 bip) public view override returns (uint256) {
        address[] storage voters = _votersFor(bip);
        uint256 rootsFor;
        for (uint256 i = 0; i < voters.length; i++) {
            rootsFor += silo.rootsOf(voters[i]); // real-time read — the bug
        }
        uint256 total = silo.totalRoots(); // real-time read — the bug
        if (total == 0) return 0;
        return (rootsFor * 10000) / total;
    }
}

/// SAFE: voting power is measured at the proposal's creation snapshot. A deposit made
/// after the proposal was nominated contributes ZERO, so flash-loaned roots can't vote.
contract SafeGovernance is GovernanceBase {
    constructor(Silo _silo) GovernanceBase(_silo) {}

    function votePercentBps(uint256 bip) public view override returns (uint256) {
        Proposal storage p = _proposals[bip];
        address[] storage voters = p.voters;
        uint256 rootsFor;
        for (uint256 i = 0; i < voters.length; i++) {
            rootsFor += silo.rootsOfAt(voters[i], p.created); // snapshot read — the fix
        }
        if (p.snapshotTotalRoots == 0) return 0;
        return (rootsFor * 10000) / p.snapshotTotalRoots;
    }
}
