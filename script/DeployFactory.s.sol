// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Script} from 'forge-std/Script.sol';

import {dAMMFactory} from "src/L1/dAMMFactory.sol";
import {FactoryConfig} from "./Config.sol";

contract DeployFactory is Script {

    function run() external returns (dAMMFactory factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        (
            address _lzEndpoint,
            address _stargateRouter
        ) = FactoryConfig.getETHGoerliConfig();

        factory = new dAMMFactory(_lzEndpoint, _stargateRouter);
        vm.stopBroadcast();
    }
}