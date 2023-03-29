#!/bin/sh
source ./.env

forge script --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv script/4_SwapFinalize.s.sol:SwapFinalize --private-key $PRIVATE_KEY --slow