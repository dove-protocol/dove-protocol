// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.15;

import {Script} from "forge-std/Script.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {L1Factory} from "../src/L1/L1Factory.sol";
import {L1Router} from "../src/L1/L1Router.sol";
import {Dove} from "../src/L1/Dove.sol";
import {IDove} from "../src/L1/interfaces/IDove.sol";

import {IL2Factory, L2Factory} from "src/L2/L2Factory.sol";
import {L2Router} from "../src/L2/L2Router.sol";
import {Pair} from "../src/L2/Pair.sol";

import {Configs} from "./Config.sol";

contract AddRemotesDAMM is Script {
    string RPC_ETH_GOERLI = vm.envString("ETH_GOERLI_RPC_URL");

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_PRIVATE_KEY");
        Configs.dAMMDeployedConfig memory config = Configs.getETHGoerliDAMMDeployedConfig();

        // --------------- Post-Deployment L1 -------------------

        vm.createSelectFork(RPC_ETH_GOERLI);
        vm.startBroadcast(deployerPrivateKey);

        L1Factory factoryL1 = L1Factory(config.factory);

        factoryL1.addTrustedRemote(config.dove, config.arbiDomain, bytes32(uint256(uint160(address(config.pairArbi)))));
        factoryL1.addTrustedRemote(config.dove, config.polyDomain, bytes32(uint256(uint160(address(config.pairPoly)))));
        factoryL1.addTrustedRemote(config.dove, config.avaxDomain, bytes32(uint256(uint160(address(config.pairAvax)))));

        L1Router routerL1 = L1Router(config.router);

        ERC20(config.token0).approve(address(routerL1), type(uint256).max);
        ERC20(config.token1).approve(address(routerL1), type(uint256).max);

        routerL1.addLiquidity(
            config.token0,
            config.token1,
            2000000000000,
            2000000000000,
            2000000000000,
            2000000000000,
            address(msg.sender),
            type(uint256).max
        );

        ERC20(config.dove).approve(address(routerL1), type(uint256).max);

        routerL1.removeLiquidity(
            config.token0,
            config.token1,
            ERC20(config.dove).balanceOf(address(msg.sender)),
            200000000000,
            200000000000,
            address(msg.sender),
            type(uint256).max
        );

        Dove(config.dove).syncL2{value: 0.5 ether}(421613, 0x87042d892c930107615360B50D0768F514522682);

        vm.stopBroadcast();
    }
}
