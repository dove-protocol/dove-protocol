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

contract SwapFinalize is Script {
    string RPC_ETH_GOERLI = vm.envString("ETH_GOERLI_RPC_URL");
    string RPC_ARBI_GOERLI = vm.envString("ARBITRUM_GOERLI_RPC_URL");

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("TESTNET_PRIVATE_KEY");
        Configs.dAMMDeployedConfig memory config = Configs.getETHGoerliDAMMDeployedConfig();

        // --------------- Post-Deployment L2 -------------------

        vm.createSelectFork(RPC_ARBI_GOERLI);
        vm.startBroadcast(deployerPrivateKey);

        L2Router(Configs.routerArbi).swapExactTokensForTokensSimple(
            22000, 0, Configs.ARB_USDT, Configs.ARB_USDC, address(msg.sender), type(uint256).max
        );

        Pair(config.pairArbi).syncToL1{value: 0.5 ether}(0.2 ether, 0.1 ether);

        vm.stopBroadcast();

        // --------------- Finalize L1 -------------------

        vm.createSelectFork(RPC_ETH_GOERLI);
        vm.startBroadcast(deployerPrivateKey);

        Dove(config.dove).finalizeSyncFromL2(Configs.ARBI_DOMAIN, 0);

        vm.stopBroadcast();
    }
}
