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

    /// RPCs
    string RPC_ETH_MAINNET = vm.envString("ETH_MAINNET_RPC_URL");
    string RPC_OP_MAINNET = vm.envString("OPTIMISM_MAINNET_RPC_URL");
    string RPC_ARB_MAINNET = vm.envString("ARBITRUM_MAINNET_RPC_URL");

    /// Deploy v1
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // --------------- Deployment L1 -------------------
        
        L1_FORK_ID = vm.createSelectFork(RPC_ETH_MAINNET);

        // deploy L1 factory 
        L1Factory factoryL1 = new L1Factory(
            0x56f52c0A1ddcD557285f7CBc782D3d83096CE1Cc, // InterchainGasPaymaster L1
            0x35231d4c2D8B8ADcB5617A638A0c4548684c7C70, // HL mailbox L1
            0x8731d54E9D02c286767d56ac03e8037C07e01e98  // SG router L1
        );

        // deploy L1 router
        L1Router routerL1 = new L1Router(address(factoryL1));

        // deploy initial dove(s)
        doveDAIUSDC = Dove(
            factoryL1.createPair(
                0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
                0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48  // USDC
            )
        );

        // set SG bridges as trusted for dove(s), L1 factory must call
        vm.broadcast(address(factoryL1));
        doveDAIUSDC.addStargateTrustedBridge(
            111,                                        // OPTIMISM chain id
            0x701a95707A0290AC8B90b3719e8EE5b210360883, // OPTIMISM SG bridge
            0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97  // L1 SG bridge
        );
        vm.broadcast(address(factoryL1));
        doveDAIUSDC.addStargateTrustedBridge(
            110,                                        // ARBITRUM chain id
            0x352d8275AAE3e0c2404d9f68f6cEE084B5bEB3DD, // ARBITRUM SG bridge
            0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97  // L1 SG bridge
        );

        // Set SGConfig for all pools
        IL2Factory.SGConfig memory sgConfigDAIUSDC =
            IL2Factory.SGConfig({srcPoolId0: 1, dstPoolId0: 1, srcPoolId1: 3, dstPoolId1: 3});

        // --------------- Switch to L2 (OPTIMISM) -------------------

        OP_FORK_ID = vm.createSelectFork(RPC_OP_MAINNET);

        // deploy L2 factory
        L2Factory factoryOP = new L2Factory(
            0x56f52c0A1ddcD557285f7CBc782D3d83096CE1Cc,  // InterchainGasPaymaster OP
            0x35231d4c2D8B8ADcB5617A638A0c4548684c7C70, // HL mailbox OP
            0xB0D502E938ed5f4df2E681fE6E419ff29631d62b, // SG router OP
            101,                                        // L1 Chain Id
            1                                           // L1 Domain
        );

        // deploy router (factory addr)
        L2Router routerOP = new L2Router(address(factoryOP));

        // Deploy pair(s)
        pairOPDAIUSDC = Pair(
            factoryOP.createPair(
                0x7F5c764cBc14f9669B88837ca1490cCa17c31607, // OP USDC
                0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1, // OP DAI
                sgConfigDAIUSDC, 
                0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
                0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC
                address(doveDAIUSDC)                        // DOVE
            )
        );


        // --------------- Switch to L2 (ARBITRUM) -------------------

        ARB_FORK_ID = vm.createSelectFork(RPC_ARB_MAINNET);

        // deploy L2 factory
        L2Factory factoryARB = new L2Factory(
            0x56f52c0A1ddcD557285f7CBc782D3d83096CE1Cc,  // InterchainGasPaymaster ARB
            0x35231d4c2D8B8ADcB5617A638A0c4548684c7C70, // HL mailbox ARB
            0xB0D502E938ed5f4df2E681fE6E419ff29631d62b, // SG router ARB
            101,                                        // L1 Chain Id
            1                                           // L1 Domain
        );

        // deploy router (factory addr)
        L2Router routerARB = new L2Router(address(factoryARB));

        pairARBDAIUSDC = Pair(
            factoryARB.createPair(
                0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8, // ARB USDC
                0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1, // ARB DAI
                sgConfigDAIUSDC, 
                0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
                0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC
                address(doveDAIUSDC)                        // DOVE
            )
        );

        // --------------- Switch back to L1 -------------------

        // L1 factory adds trusted remotes to dove(s) for each pair(s)
        doveDAIUSDC.addTrustedRemote(
            10,                                               // OP Domain
            bytes32(uint256(uint160(address(pairOPDAIUSDC)))) // pairOPDAIUSDC
        );
        //doveDAIUSDC.addTrustedRemote(
        //10,                                                // ARB Domain???
        //bytes32(uint256(uint160(address(pairARBDAIUSDC)))) // pairARBDAIUSDC
        //);

        vm.stopBroadcast();
    }
}
