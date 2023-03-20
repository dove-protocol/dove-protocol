// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.15;

import {Script} from "forge-std/Script.sol";

import {L1Factory} from "../src/L1/L1Factory.sol";
import {L1Router} from "../src/L1/L1Router.sol";
import {Dove} from "../src/L1/Dove.sol";

import {IL2Factory, L2Factory} from "src/L2/L2Factory.sol";
import {L2Router} from "../src/L2/L2Router.sol";
import {Pair} from "../src/L2/Pair.sol";

contract testnetDeployDAMM is Script {
    /// Dove(s)
    Dove doveUSDTUSDC;

    /// Pair(s)
    Pair pairARBUSDTUSDC;
    Pair pairPOLYUSDTUSDC;
    Pair pairAVAXUSDTUSDC;

    /// Forks
    uint256 L1_FORK_ID;
    uint256 ARB_FORK_ID;
    uint256 POLY_FORK_ID;
    uint256 AVAX_FORK_ID;

    /// Chain IDs
    uint16 constant L1_CHAIN_ID = 10121;   // ETH goerli
    uint16 constant ARB_CHAIN_ID = 10143;  // ARB goerli
    uint16 constant POLY_CHAIN_ID = 10109; // POLY mumbai
    uint16 constant AVAX_CHAIN_ID = 10106; // AVAX fuji

    /// Hyperlane INTERCHAIN GAS PAYMASTERS
    // L1 goerli
    address constant gasMasterL1 = 0xF90cB82a76492614D07B82a7658917f3aC811Ac1;
    // ARB goerli
    address constant gasMasterARB = 0xF90cB82a76492614D07B82a7658917f3aC811Ac1;
    // POLY mumbai
    address constant gasMasterPOLY = 0xF90cB82a76492614D07B82a7658917f3aC811Ac1;
    // AVAX fuji
    address constant gasMasterAVAX = 0xF90cB82a76492614D07B82a7658917f3aC811Ac1;

    /// Hyperlane MAILBOXES
    // L1 goerli
    address constant mailboxL1 = 0xCC737a94FecaeC165AbCf12dED095BB13F037685;
    // ARB goerli
    address constant mailboxARB = 0xCC737a94FecaeC165AbCf12dED095BB13F037685;
    // POLY mumbai
    address constant mailboxPOLY = 0xCC737a94FecaeC165AbCf12dED095BB13F037685;
    // AVAX fuji
    address constant mailboxAVAX = 0xCC737a94FecaeC165AbCf12dED095BB13F037685;

    /// Hyperlane DOMAINS
    uint32 constant L1_DOMAIN = 5;       // ETH goerli
    uint32 constant ARB_DOMAIN = 137;    // ARB goerli
    uint32 constant POLY_DOMAIN = 80001; // POLY mumbai
    uint32 constant AVAX_DOMAIN = 43113; // AVAX fuji

    /// Stargate BRIDGES
    // L1 goerli
    address constant sgBridgeL1 = 0xE6612eB143e4B350d55aA2E229c80b15CA336413;
    // ARB goerli
    address constant sgBridgeARB = 0xd43cbCC7642C1Df8e986255228174C2cca58d65b;
    // POLY mumbai
    address constant sgBridgePOLY = 0x629B57D89b1739eE1C0c0fD9eab426306e11cF42;
    // AVAX fuji
    address constant sgBridgeAVAX = 0x29fBC4E4092Db862218c62a888a00F9521619230;

    /// Stargate ROUTERS
    // L1 goerli
    address constant sgRouterL1 = 0x7612aE2a34E5A363E137De748801FB4c86499152;
    // ARB goerli
    address constant sgRouterARB = 0xb850873f4c993Ac2405A1AdD71F6ca5D4d4d6b4f;
    // POLY mumbai
    address constant sgRouterPOLY = 0x817436a076060D158204d955E5403b6Ed0A5fac0;
    // AVAX fuji
    address constant sgRouterAVAX = 0x13093E05Eb890dfA6DacecBdE51d24DabAb2Faa1;

    /// TOKENS
    // L1 goerli
    address constant USDT = 0x5BCc22abEC37337630C0E0dd41D64fd86CaeE951;
    address constant USDC = 0xDf0360Ad8C5ccf25095Aa97ee5F2785c8d848620;
    // ARB goerli
    address constant ARB_USDT = 0x533046F316590C19d99c74eE661c6d541b64471C;
    address constant ARB_USDC = 0x6aAd876244E7A1Ad44Ec4824Ce813729E5B6C291;
    // POLY mumbai
    address constant POLY_USDT = 0x533046F316590C19d99c74eE661c6d541b64471C;
    address constant POLY_USDC = 0x742DfA5Aa70a8212857966D491D67B09Ce7D6ec7;
    // AVAX fuji
    address constant AVAX_USDT = 0x134Dc38AE8C853D1aa2103d5047591acDAA16682;
    address constant AVAX_USDC = 0x4A0D1092E9df255cf95D72834Ea9255132782318;

    /// RPCs
    string RPC_ETH_GOELRI = vm.envString("ETH_GOERLI_RPC_URL");
    string RPC_ARB_GOELRI = vm.envString("ARBITRUM_MAINNET_RPC_URL");
    string RPC_POLY_MUMBAI = vm.envString("POLYGON_MUMBAI_RPC_URL");
    string RPC_AVAX_FUJI = vm.envString("AVALANCHE_FUJI_RPC_URL");

    /// Deploy v1
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // --------------- Deployment L1 -------------------
        
        L1_FORK_ID = vm.createSelectFork(RPC_ETH_GOELRI);

        // deploy L1 factory 
        L1Factory factoryL1 = new L1Factory(
            gasMasterL1, // InterchainGasPaymaster L1 Goerli done
            mailboxL1,   // HL mailbox L1 Goerli done
            sgRouterL1   // SG router L1 Goerli done
        );

        // deploy L1 router
        L1Router routerL1 = new L1Router(address(factoryL1));

        // deploy initial dove(s)
        doveUSDTUSDC = Dove(
            factoryL1.createPair(USDT, USDC)
        );

        // set SG bridges as trusted for dove(s), L1 factory must call
        vm.broadcast(address(factoryL1));
        doveUSDTUSDC.addStargateTrustedBridge(ARB_CHAIN_ID, sgBridgeARB, sgBridgeL1);

        vm.broadcast(address(factoryL1));
        doveUSDTUSDC.addStargateTrustedBridge(POLY_CHAIN_ID, sgBridgePOLY, sgBridgeL1);

        vm.broadcast(address(factoryL1));
        doveUSDTUSDC.addStargateTrustedBridge(AVAX_CHAIN_ID, sgBridgeAVAX, sgBridgeL1);

        // Set SGConfig for all pools
        IL2Factory.SGConfig memory sgConfigUSDTUSDC =
            IL2Factory.SGConfig({srcPoolId0: 1, dstPoolId0: 1, srcPoolId1: 2, dstPoolId1: 2});

        // --------------- Switch to L2 (ARBITRUM) -------------------

        ARB_FORK_ID = vm.createSelectFork(RPC_ARB_GOELRI);

        // deploy L2 factory
        L2Factory factoryARB = new L2Factory(
            gasMasterARB,
            mailboxARB,
            sgRouterARB,
            L1_CHAIN_ID,
            L1_DOMAIN
        );

        // deploy router (factory addr)
        L2Router routerARB = new L2Router(address(factoryARB));

        // Deploy pair(s)
        pairARBUSDTUSDC = Pair(
            factoryARB.createPair(
                ARB_USDC,
                ARB_USDT,
                sgConfigUSDTUSDC, 
                USDT,
                USDC,
                address(doveUSDTUSDC)
            )
        );


        // --------------- Switch to L2 (POLYGON) -------------------

        POLY_FORK_ID = vm.createSelectFork(RPC_POLY_MUMBAI);

        // deploy L2 factory
        L2Factory factoryPOLY = new L2Factory(
            gasMasterPOLY,
            mailboxPOLY,
            sgRouterPOLY,
            L1_CHAIN_ID,
            L1_DOMAIN
        );

        // deploy router (factory addr)
        L2Router routerPOLY = new L2Router(address(factoryPOLY));

        pairPOLYUSDTUSDC = Pair(
            factoryARB.createPair(
                POLY_USDC,
                POLY_USDT,
                sgConfigUSDTUSDC, 
                USDT,
                USDC,
                address(doveUSDTUSDC)
            )
        );

        // --------------- Switch to "L2" (AVALANCHE) -------------------

        AVAX_FORK_ID = vm.createSelectFork(RPC_AVAX_FUJI);

        // deploy L2 factory
        L2Factory factoryAVAX = new L2Factory(
            gasMasterAVAX,
            mailboxAVAX,
            sgRouterAVAX,
            L1_CHAIN_ID,
            L1_DOMAIN
        );

        // deploy router (factory addr)
        L2Router routerAVAX = new L2Router(address(factoryAVAX));

        // Deploy pair(s)
        pairAVAXUSDTUSDC = Pair(
            factoryAVAX.createPair(
                AVAX_USDC,
                AVAX_USDT,
                sgConfigUSDTUSDC, 
                AVAX_USDT,
                AVAX_USDC,
                address(doveUSDTUSDC)
            )
        );

        // --------------- Switch back to L1 -------------------

        vm.selectFork(L1_FORK_ID);

        // L1 factory adds trusted remotes to dove(s) for each pair(s)
        doveUSDTUSDC.addTrustedRemote(
            ARB_DOMAIN,
            bytes32(uint256(uint160(address(pairARBUSDTUSDC))))
        );
        doveUSDTUSDC.addTrustedRemote(
            POLY_DOMAIN,
            bytes32(uint256(uint160(address(pairPOLYUSDTUSDC))))
        );
        doveUSDTUSDC.addTrustedRemote(
            AVAX_DOMAIN,
            bytes32(uint256(uint160(address(pairAVAXUSDTUSDC))))
        );

        vm.stopBroadcast();
    }
}
