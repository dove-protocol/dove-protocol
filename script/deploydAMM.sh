#!/bin/sh
source ./.env

forge script --rpc-url $ETH_GOERLI_RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv script/DeployDAMM.s.sol:DeployDAMM