// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/StdUtils.sol";
import "forge-std/console.sol";

import {Codec} from "src/Codec.sol";

contract Typer is Test {
    function assertType(uint256 expectedType, bytes calldata payload) public {
        assertEq(Codec.getType(payload), expectedType);
    }
}

contract CodecTest is Test {

    uint16 syncID_;
    Codec.SyncerMetadata sm;
    Codec.PartialSync pSyncA;
    Codec.PartialSync pSyncB;

    function testEncodeAndDecodeSyncToL1(
        uint16 syncID,
        address L1Token0,
        uint128 pairVoucherBalance0,
        uint128 voucherDelta0, 
        uint128 balance0,
        address L1Token1,
        uint128 pairVoucherBalance1,
        uint128 voucherDelta1,
        uint128 balance1,
        address syncer,
        uint64 syncerPercentage
    ) public {
        syncerPercentage = uint64(StdUtils.bound(uint(syncerPercentage), 0, 10000));

        bytes memory encoded = Codec.encodeSyncToL1(
            syncID,
            L1Token0,
            pairVoucherBalance0,
            voucherDelta0,
            balance0,
            L1Token1,
            pairVoucherBalance1,
            voucherDelta1,
            balance1,
            syncer,
            syncerPercentage
        );

        (
            syncID_,
            sm,
            pSyncA,
            pSyncB
        ) = Codec.decodeSyncToL1(encoded);


        Typer typer = new Typer();
        typer.assertType(Codec.SYNC_TO_L1, encoded);

        assertEq(syncID_, syncID);
        assertEq(sm.syncer, syncer);
        assertEq(sm.syncerPercentage, syncerPercentage);
        assertEq(pSyncA.token, L1Token0);
        assertEq(pSyncA.tokensForDove, pairVoucherBalance0);
        assertEq(pSyncA.earmarkedAmount, voucherDelta0);
        assertEq(pSyncA.pairBalance, balance0);
        assertEq(pSyncB.token, L1Token1);
        assertEq(pSyncB.tokensForDove, pairVoucherBalance1);
        assertEq(pSyncB.earmarkedAmount, voucherDelta1);
        assertEq(pSyncB.pairBalance, balance1);
    }
}