#!/bin/sh
source ./.env

export TARGET_LAYER="arbitrum"
forge script --rpc-url $ARBI_GOERLI_RPC_URL --broadcast --verify --etherscan-api-key $ARBISCAN_KEY -vvvv script/DeployL2AMM.s.sol:DeployL2AMM --ffi --verifier-url https://api-goerli.arbiscan.io/api --slow

export TARGET_LAYER="polygon"
forge script --rpc-url $POLYGON_MUMBAI_RPC_URL --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv script/DeployL2AMM.s.sol:DeployL2AMM --ffi --verifier-url https://api-testnet.polygonscan.com/api --slow