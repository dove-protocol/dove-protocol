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

contract DeployAMM is Script {
    string RPC_URL;

    /// Deploy v1
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_PRIVATE_KEY");
        string memory layer = vm.envString("TARGET_LAYER");
        Configs.AMMConfig memory config;

        IL2Factory.SGConfig memory sgConfigUSDTUSDC =
            IL2Factory.SGConfig({srcPoolId0: 1, dstPoolId0: 1, srcPoolId1: 2, dstPoolId1: 2});

        if (keccak256(abi.encodePacked(layer)) == keccak256(abi.encodePacked("arbitrum"))) {
            config = Configs.getArbiGoerliConfig();
            RPC_URL = vm.envString("ARBITRUM_GOERLI_RPC_URL");
        } else if (keccak256(abi.encodePacked(layer)) == keccak256(abi.encodePacked("polygon"))) {
            config = Configs.getPolygonMumbaiConfig();
            RPC_URL = vm.envString("POLYGON_MUMBAI_RPC_URL");
        } else if (keccak256(abi.encodePacked(layer)) == keccak256(abi.encodePacked("avalanche"))) {
            config = Configs.getAvaxFujiConfig();
            RPC_URL = vm.envString("AVAX_FUJI_RPC_URL");
        } else {
            revert("Invalid network");
        }

        // --------------- Deployment L2 -------------------

        vm.createSelectFork(RPC_URL);
        vm.startBroadcast(deployerPrivateKey);

        // deploy L2 factory
        L2Factory factoryARB = new L2Factory(
            config.hlGasMaster,
            config.hlMailbox,
            config.sgRouter,
            config.sgChainId,
            config.hlDomainId
        );

        // deploy router (factory addr)
        L2Router routerARB = new L2Router(address(factoryARB));

        // Deploy pair
        Pair pair = Pair(
            factoryARB.createPair(
                config.token0, config.token1, sgConfigUSDTUSDC, config.L1Token0, config.L1Token1, config.dove
            )
        );
        vm.stopBroadcast();
    }
}
