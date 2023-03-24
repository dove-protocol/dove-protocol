#!/bin/sh
source ./.env

forge script --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv script/3_AddRemotesDAMM.s.sol:AddRemotesDAMM --private-key $PRIVATE_KEY --slow