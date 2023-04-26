// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { L1ToL2SyncActor } from "./actors/L1ToL2SyncActor.sol";

import { BaseInvariant } from "./BaseInvariant.t.sol";
import { Minter } from "../utils/Minter.sol";

import { Codec } from "../../src/Codec.sol";

contract L1ToL2SyncInvariant is BaseInvariant {

    L1ToL2SyncActor public actor;

    function setUp() external {
        _setUp();
        // deploy actor
        actor = new L1ToL2SyncActor();
        targetContract(address(actor));
    }

    function invariantL1ToL2ReserveSync() external {
        // fetch reserves
        uint128 doveReserve0 = dove.reserve0();
        uint128 doveReserve1 = dove.reserve1();
        address l1token0 = dove.token0();

        vm.selectFork(L2_FORK_ID);

        // craft payload
        bytes memory payload = Codec.encodeSyncToL2(l1token0, doveReserve0, doveReserve1);
        // spoof hyperlane message arrival on L2
        vm.prank(address(pair.mailbox()));
        pair.handle(L1_DOMAIN, bytes32(uint256(uint160(address(dove)))), payload);

        // fetch reserves after the message that dove.syncL2() sends is relayed by hyperlane
        uint256 pairReserve0 = pair.balance0();
        uint256 pairReserve1 = pair.balance1();

        // assert the sync call was successful
        assertEq(
            pairReserve1, 
            doveReserve0
        );
        assertEq(
            pairReserve0, 
            doveReserve1
        );

        // reset fork
        vm.selectFork(L1_FORK_ID);
    }
}