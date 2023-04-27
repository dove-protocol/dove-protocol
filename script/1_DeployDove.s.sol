// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.15;

import {Script} from "forge-std/Script.sol";

import {L1Factory} from "../src/L1/L1Factory.sol";
import {L1Router} from "../src/L1/L1Router.sol";
import {Dove} from "../src/L1/Dove.sol";

import {IL2Factory, L2Factory} from "src/L2/L2Factory.sol";
import {L2Router} from "../src/L2/L2Router.sol";
import {Pair} from "../src/L2/Pair.sol";

import {Configs} from "./Config.sol";

contract DeployDove is Script {
    string RPC_ETH_GOERLI = vm.envString("ETH_GOERLI_RPC_URL");

    /// Deploy v1
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_PRIVATE_KEY");
        Configs.dAMMConfig memory config = Configs.getETHGoerliDAMMConfig();

        // --------------- Deployment L1 -------------------

        vm.createSelectFork(RPC_ETH_GOERLI);
        vm.startBroadcast(deployerPrivateKey);

        // deploy L1 factory
        L1Factory factoryL1 = new L1Factory(
            config.hlGasMaster,
            config.hlMailbox,
            config.sgRouterL1
        );

        // deploy L1 router
        L1Router routerL1 = new L1Router(address(factoryL1));

        // deploy initial dove(s)
        Dove doveUSDTUSDC = Dove(factoryL1.createPair(Configs.USDT, Configs.USDC));

        // set SG bridges as trusted for dove(s), L1 factory must call
        // vm.broadcast(address(factoryL1));
        factoryL1.addStargateTrustedBridge(
            address(doveUSDTUSDC), config.arbiChainId, config.sgBridgeArbi, config.sgBridgeL1
        );

        // vm.broadcast(address(factoryL1));
        factoryL1.addStargateTrustedBridge(
            address(doveUSDTUSDC), config.polyChainId, config.sgBridgePoly, config.sgBridgeL1
        );

        // vm.broadcast(address(factoryL1));
        factoryL1.addStargateTrustedBridge(
            address(doveUSDTUSDC), config.avaxChainId, config.sgBridgeAvax, config.sgBridgeL1
        );

        vm.stopBroadcast();
    }
}