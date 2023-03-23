#!/bin/sh
source ./.env

forge script --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv script/testnetDeploy.s.sol:testnetDeployDAMM --private-key $PRIVATE_KEY --slow