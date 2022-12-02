// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity ^0.8.15;

// import {Script} from "forge-std/Script.sol";

// import {dAMM} from "src/L1/dAMM.sol";
// import {dAMMConfigs} from "./Config.sol";

// interface ERC20 {
//     function mint(address, uint256) external;

//     function approve(address, uint256) external returns (bool);
// }

// /// @notice A very simple deployment script
// contract DeployDAMM is Script {
//     function run() external returns (dAMM damm) {
//         uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
//         vm.startBroadcast(deployerPrivateKey);

//         dAMMConfigs.dAMMConfig memory config = dAMMConfigs.getETHGoerliConfig();
//         damm = new dAMM(config.factory);
//         damm.initialize(config.token0, config.token1);

//         // ONLY FOR TESTNET
//         // set SG bridges
//         damm.addStargateTrustedBridge(
//             10143, 0xd43cbCC7642C1Df8e986255228174C2cca58d65b, 0xE6612eB143e4B350d55aA2E229c80b15CA336413
//         );
//         damm.addStargateTrustedBridge(
//             10109, 0x629B57D89b1739eE1C0c0fD9eab426306e11cF42, 0xE6612eB143e4B350d55aA2E229c80b15CA336413
//         );
//         vm.stopBroadcast();
//         this.postDeploymentTestnet(damm, config);
//     }

//     function postDeploymentTestnet(dAMM damm, dAMMConfigs.dAMMConfig memory config) external {
//         uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
//         vm.startBroadcast(deployerPrivateKey);
//         address deployer = vm.addr(deployerPrivateKey);
//         // mint fake stables
//         // usdc
//         ERC20(config.token0).mint(deployer, 10 ** 13);
//         // usdt
//         ERC20(config.token1).mint(deployer, 10 ** 13);
//         // provide liquidity
//         ERC20(config.token0).approve(address(damm), 10 ** 13);
//         ERC20(config.token1).approve(address(damm), 10 ** 13);
//         damm.provide(10 ** 13, 10 ** 13);
//         vm.stopBroadcast();
//     }
// }
