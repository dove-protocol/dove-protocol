#!/bin/sh
source ./.env

export TARGET_LAYER="arbitrum"
forge script --broadcast --verify --etherscan-api-key $ARBISCAN_KEY -vvvv script/2_DeployAMM.s.sol:DeployAMM --ffi --verifier-url https://api-goerli.arbiscan.io/api --slow

export TARGET_LAYER="polygon"
forge script --broadcast --verify --etherscan-api-key $POLYGONSCAN_KEY -vvvv script/2_DeployAMM.s.sol:DeployAMM --ffi --verifier-url https://api-testnet.polygonscan.com/api --slow

export TARGET_LAYER="avalanche"
forge script --broadcast --verify --etherscan-api-key $SNOWTRACE_KEY -vvvv script/2_DeployAMM.s.sol:DeployAMM --ffi --verifier-url https://api.avax-test.network/ext/bc/C/rpc --slow