// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {
    Forta,
    CryptoVault,
    LegacyToken,
    DoubleEntryPoint,
    IDetectionBot,
    IForta,
    DelegateERC20
} from "../src/levels/DoubleEntryPoint.sol";
import {IERC20} from "openzeppelin-contracts-08/token/ERC20/IERC20.sol";

/// Ethernaut #26 "DoubleEntryPoint" → SC02 logic (a "double entry point") — a DEFENSIVE level.
/// The vault's underlying (DET) can't be swept directly, but sweeping LegacyToken (LGT) delegates
/// its transfer to DET, draining the underlying. The solve is to register a Forta detection bot that
/// raises an alert when `delegateTransfer`'s `origSender` is the vault, so the guarded transfer
/// reverts. Win: a bot is registered and the sweep no longer succeeds.
contract DetectionBot is IDetectionBot {
    address public vault;
    IForta public forta;

    constructor(address _vault, IForta _forta) {
        vault = _vault;
        forta = _forta;
    }

    function handleTransaction(address user, bytes calldata) external override {
        // msgData = delegateTransfer(to, value, origSender); origSender sits at calldata 0xa8
        address origSender;
        assembly {
            origSender := calldataload(0xa8)
        }
        if (origSender == vault) {
            forta.raiseAlert(user);
        }
    }
}

contract DoubleEntryPointTest is Test {
    address player = makeAddr("player");
    address sink = makeAddr("sink");

    function test_solve_doubleEntryPoint() public {
        // Mirror the level wiring.
        Forta forta = new Forta();
        CryptoVault vault = new CryptoVault(sink);
        LegacyToken lgt = new LegacyToken();
        DoubleEntryPoint det = new DoubleEntryPoint(address(lgt), address(vault), address(forta), player);
        lgt.delegateToNewContract(DelegateERC20(address(det)));
        vault.setUnderlying(address(det)); // DET is the protected underlying (100 ether minted to vault)
        lgt.mint(address(vault), 100 ether); // LGT in the vault = the sweep amount

        // The vulnerability: sweeping LGT drains DET (the double entry point) — confirm without a bot.
        uint256 snap = vm.snapshot();
        vault.sweepToken(IERC20(address(lgt)));
        assertEq(det.balanceOf(address(vault)), 0, "without a bot, sweeping LGT drains the underlying DET");
        vm.revertTo(snap);

        // The DEFENSE: register a detection bot for the player.
        DetectionBot bot = new DetectionBot(address(vault), forta);
        vm.prank(player);
        forta.setDetectionBot(address(bot));

        // Now the sweep is detected and reverts; the underlying is safe.
        vm.expectRevert(bytes("Alert has been triggered, reverting"));
        vault.sweepToken(IERC20(address(lgt)));

        assertEq(address(forta.usersDetectionBots(player)), address(bot), "bot registered");
        assertEq(det.balanceOf(address(vault)), 100 ether, "underlying DET protected");
    }
}
