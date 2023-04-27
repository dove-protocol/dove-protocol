#!/bin/sh
source ./.env

forge script --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv script/1_DeployDove.s.sol:DeployDove --private-key $PRIVATE_KEY --slow