// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity ^0.8.15;

// import {Script} from "forge-std/Script.sol";
// import {console2} from "forge-std/console2.sol";

// import {AMM} from "src/L2/AMM.sol";
// import {AMMConfigs} from "./Config.sol";

// interface ERC20 {
//     function mint(address, uint256) external;
//     function approve(address, uint256) external returns (bool);
// }

// /// @notice A very simple deployment script
// contract DeployL2AMM is Script {
//     function run() external returns (AMM amm) {
//         console2.log(vm.projectRoot());
//         console2.log("Deploying new AMM...");
//         amm = deployAMM();
//     }

//     function deployAMM() internal returns (AMM amm) {
//         uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
//         string memory network = vm.envString("TARGET_NETWORK");
//         string memory layer = vm.envString("TARGET_LAYER");
//         AMMConfigs.AMMConfig memory config;

//         vm.startBroadcast(deployerPrivateKey);

//         // assume target network is goerli in every case
//         if (keccak256(abi.encodePacked(layer)) == keccak256(abi.encodePacked("arbitrum"))) {
//             config = AMMConfigs.getArbiGoerliConfig();
//         } else if (keccak256(abi.encodePacked(layer)) == keccak256(abi.encodePacked("polygon"))) {
//             config = AMMConfigs.getPolygonMumbaiConfig();
//         } else if (keccak256(abi.encodePacked(layer)) == keccak256(abi.encodePacked("avax"))) {
//             config = AMMConfigs.getAvaxFujiConfig();
//         } else {
//             revert("Invalid network");
//         }

//         amm =
//         new AMM(config.token0, config.L1Token0, config.token1, config.L1Token1, config.lzEndpoint, config.stargateRouter, config.L1Target, config.destChainId);

//         // should be done FROM the L1
//         //amm.setReserves(1000000000000, 1000000000000);

//         // only mint and approve if on a testnet
//         if (keccak256(abi.encodePacked(network)) != keccak256(abi.encodePacked("mainnet"))) {
//             // usdc
//             ERC20(config.token0).mint(msg.sender, 10 ** 12);
//             // usdt
//             ERC20(config.token1).mint(msg.sender, 10 ** 12);

//             ERC20(config.token0).approve(address(amm), 10 ** 12);
//             ERC20(config.token1).approve(address(amm), 10 ** 12);
//         }

//         vm.stopBroadcast();
//     }
// }
