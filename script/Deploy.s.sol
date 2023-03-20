// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.15;

import {Script} from "forge-std/Script.sol";

import {L1Factory} from "../src/L1/L1Factory.sol";
import {L1Router} from "../src/L1/L1Router.sol";
import {Dove} from "../src/L1/Dove.sol";

import {IL2Factory, L2Factory} from "src/L2/L2Factory.sol";
import {L2Router} from "../src/L2/L2Router.sol";
import {Pair} from "../src/L2/Pair.sol";

contract DeployDAMM is Script {
    /// Dove(s)
    Dove doveDAIUSDC;

    /// Pair(s)
    Pair pairOPDAIUSDC;
    Pair pairARBDAIUSDC;

    /// Forks
    uint256 L1_FORK_ID;
    uint256 OP_FORK_ID;
    uint256 ARB_FORK_ID;

     /// Chain IDs
    uint16 constant L1_CHAIN_ID = 101;  // ETH 
    uint16 constant OP_CHAIN_ID = 111;  // OP 
    uint16 constant ARB_CHAIN_ID = 110; // ARB

    /// Hyperlane INTERCHAIN GAS PAYMASTERS
    // L1
    address constant gasMasterL1 = 0x56f52c0A1ddcD557285f7CBc782D3d83096CE1Cc;
    // OP
    address constant gasMasterOP = 0x56f52c0A1ddcD557285f7CBc782D3d83096CE1Cc;
    // ARB
    address constant gasMasterARB = 0x56f52c0A1ddcD557285f7CBc782D3d83096CE1Cc;

    /// Hyperlane MAILBOXES
    // L1
    address constant mailboxL1 = 0x35231d4c2D8B8ADcB5617A638A0c4548684c7C70;
    // OP
    address constant mailboxOP = 0x35231d4c2D8B8ADcB5617A638A0c4548684c7C70;
    // ARB
    address constant mailboxARB = 0x35231d4c2D8B8ADcB5617A638A0c4548684c7C70;

    /// Hyperlane DOMAINS
    uint32 constant L1_DOMAIN = 1;      // ETH
    uint32 constant OP_DOMAIN = 10;     // OP
    uint32 constant ARB_DOMAIN = 42161; // ARB

    /// Stargate BRIDGES
    // L1 goerli
    address constant sgBridgeL1 = 0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97;
    // OP
    address constant sgBridgeOP = 0x701a95707A0290AC8B90b3719e8EE5b210360883;
    // ARB
    address constant sgBridgeARB = 0x352d8275AAE3e0c2404d9f68f6cEE084B5bEB3DD;

    /// Stargate ROUTERS
    // L1
    address constant sgRouterL1 = 0x8731d54E9D02c286767d56ac03e8037C07e01e98;
    // OP
    address constant sgRouterOP = 0xB0D502E938ed5f4df2E681fE6E419ff29631d62b;
    // ARB
    address constant sgRouterARB = 0x53Bf833A5d6c4ddA888F69c22C88C9f356a41614;

    /// TOKENS
    // L1 
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // OP
    address constant OP_DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address constant OP_USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    // ARB 
    address constant ARB_DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address constant ARB_USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    

    /// RPCs
    string RPC_ETH_MAINNET = vm.envString("ETH_GOERLI_RPC_URL");
    string RPC_OP_MAINNET = vm.envString("OPTIMISM_MAINNET_RPC_URL");
    string RPC_ARB_MAINNET = vm.envString("ARBITRUM_MAINNET_RPC_URL");

    /// Deploy v1
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // --------------- Deployment L1 -------------------
        
        L1_FORK_ID = vm.createSelectFork(RPC_ETH_MAINNET);

        // deploy L1 factory 
        L1Factory factoryL1 = new L1Factory(gasMasterL1, mailboxL1, sgRouterL1);

        // deploy L1 router
        L1Router routerL1 = new L1Router(address(factoryL1));

        // deploy initial dove(s)
        doveDAIUSDC = Dove(
            factoryL1.createPair(DAI, USDC)
        );

        // set SG bridges as trusted for dove(s), L1 factory must call
        vm.broadcast(address(factoryL1));
        doveDAIUSDC.addStargateTrustedBridge(OP_CHAIN_ID, sgBridgeOP, sgBridgeL1);

        vm.broadcast(address(factoryL1));
        doveDAIUSDC.addStargateTrustedBridge(ARB_CHAIN_ID, sgBridgeARB, sgBridgeL1);

        // Set SGConfig for all pools
        IL2Factory.SGConfig memory sgConfigDAIUSDC =
            IL2Factory.SGConfig({srcPoolId0: 1, dstPoolId0: 1, srcPoolId1: 3, dstPoolId1: 3});

        // --------------- Switch to L2 (OPTIMISM) -------------------

        OP_FORK_ID = vm.createSelectFork(RPC_OP_MAINNET);

        // deploy L2 factory
        L2Factory factoryOP = new L2Factory(
            gasMasterOP,
            mailboxOP,
            sgRouterOP,
            L1_CHAIN_ID,
            L1_DOMAIN
        );

        // deploy router (factory addr)
        L2Router routerOP = new L2Router(address(factoryOP));

        // Deploy pair(s)
        pairOPDAIUSDC = Pair(
            factoryOP.createPair(
                OP_USDC,
                OP_DAI,
                sgConfigDAIUSDC, 
                DAI,
                USDC,
                address(doveDAIUSDC)
            )
        );


        // --------------- Switch to L2 (ARBITRUM) -------------------

        ARB_FORK_ID = vm.createSelectFork(RPC_ARB_MAINNET);

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

        pairARBDAIUSDC = Pair(
            factoryARB.createPair(
                ARB_USDC,
                ARB_DAI,
                sgConfigDAIUSDC, 
                DAI,
                USDC,
                address(doveDAIUSDC)
            )
        );

        // --------------- Switch back to L1 -------------------

        vm.selectFork(L1_FORK_ID);

        // L1 factory adds trusted remotes to dove(s) for each pair(s)
        doveDAIUSDC.addTrustedRemote(
            OP_DOMAIN,
            bytes32(uint256(uint160(address(pairOPDAIUSDC))))
        );
        doveDAIUSDC.addTrustedRemote(
            ARB_DOMAIN,
            bytes32(uint256(uint160(address(pairARBDAIUSDC))))
        );

        vm.stopBroadcast();
    }
}
