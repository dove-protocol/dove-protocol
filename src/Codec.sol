// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.15;

library Codec {
    uint256 public constant BURN_VOUCHERS = 1;
    uint256 public constant SYNC_TO_L1 = 2;
    uint256 public constant SYNC_TO_L2 = 3;

    function getType(bytes calldata payload) internal pure returns (uint256 msgType) {
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, payload.offset, 32)
            msgType := shr(253, mload(ptr))

        }
    }

    /*##############################################################################################################################*/

    struct PartialSync {
        address token;
        uint128 tokensForDove; // tokens to send to Dove, aka vouchers held by pair burnt
        uint128 earmarkedAmount; // tokens to earmark aka vouchers
        uint128 pairBalance; // token balance of the pair
    }

    struct SyncerMetadata {
        uint64 syncerPercentage;
        address syncer;
    }

    function encodeSyncToL1(
        uint16 syncID,
        address L1Token0,
        uint128 pairVoucherBalance0,
        uint128 voucherDelta0, 
        uint256 balance0,
        address L1Token1,
        uint128 pairVoucherBalance1,
        uint128 voucherDelta1,
        uint256 balance1,
        address syncer,
        uint64 syncerPercentage
    ) internal pure returns (bytes memory payload) {
        assembly {
            payload := mload(0x40) // free mem ptr
            mstore(payload, 0xC0) // store length
            /*
                fpacket is split into the following, left to right
                3 bits  | 16 bits | 14 bits | 160 bits |
                --------|---------|---------|----------| = 193 bits occupied
                msgType | syncID  | syncer% | syncer   |
            */
            let fpacket := shl(253, SYNC_TO_L1) // 3 bits
            fpacket := or(fpacket, shl(237, syncID)) // 16 bits
            fpacket := or(fpacket, shl(223, syncerPercentage)) // 14 bits
            fpacket := or(fpacket, shl(63, syncer)) // 160 bits
            mstore(add(payload, 0x20), fpacket) // 1 memory "slot" used so far
            /*
            mem   |--------- 0x40 ---------|--------- 0x60 ---------|--------- 0x80 ---------|--------- 0xA0 ---------|--------- 0xC0 ---------|
            var   |      L1T0     | TFD0   | TFD0 |    EA0    | PB0 | PB0 |   L1T1   |  TFD1 | TFD1 |    EA1    | PB1 | PB1 |   0x00   | 0x00 |
            bytes |       20      |  12    |  4   |    16     | 12  |  4  |    20    |   8   | 8    |    16     |  8  | 8   |    0     |  0   |
            bits  |      160      |  96    |  32  |    128    | 96  |  32 |    160   |   64  | 64   |    128    |  64 | 64  |    0     |  0   |
                                  >---------------<           >-----------<          >--------------<           >-----------<
            */
            fpacket := shl(96, L1Token0)
            // at this point, only the 96 upper bits are saved, 32 bits left to save
            fpacket := or(fpacket, shr(32, pairVoucherBalance0))
            mstore(add(payload, 0x40), fpacket)

            fpacket := shl(224, pairVoucherBalance0)
            fpacket := or(fpacket, shl(96, voucherDelta0))
            fpacket := or(fpacket, shr(32, balance0))
            mstore(add(payload, 0x60), fpacket)

            fpacket := shl(224, balance0)
            fpacket := or(fpacket, shl(64, L1Token1))
            fpacket := or(fpacket, shr(64, pairVoucherBalance1))
            mstore(add(payload, 0x80), fpacket)

            fpacket := shl(192, pairVoucherBalance1)
            fpacket := or(fpacket, shl(64, voucherDelta1))
            fpacket := or(fpacket, shr(64, balance1))
            mstore(add(payload, 0xA0), fpacket)

            fpacket := shl(192, balance1)
            mstore(add(payload, 0xC0), fpacket)
            // update free mem ptr
            mstore(0x40, add(payload, 0xe0))
        }
    }

    function decodeSyncToL1(bytes memory _payload)
        internal
        pure
        returns (uint16 syncID, SyncerMetadata memory sm, PartialSync memory pSyncA, PartialSync memory pSyncB)
    {
        assembly {
            let fpacket := mload(add(_payload, 0x20))
            //msgType := shr(253, fpacket)
            syncID := and(shr(237, fpacket), 0xFFFF)
            // syncer%
            mstore(sm, and(shr(223, fpacket), 0x3FFF))
            mstore(add(sm, 0x20), and(shr(63, fpacket), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
            /*
            mem   |--------- 0x40 ---------|--------- 0x60 ---------|--------- 0x80 ---------|--------- 0xA0 ---------|--------- 0xC0 ---------|
            var   |      L1T0     | TFD0   | TFD0 |    EA0    | PB0 | PB0 |   L1T1   |  TFD1 | TFD1 |    EA1    | PB1 | PB1 |   0x00   | 0x00 |
            bytes |       20      |  12    |  4   |    16     | 12  |  4  |    20    |   8   | 8    |    16     |  8  | 8   |    0     |  0   |
            bits  |      160      |  96    |  32  |    128    | 96  |  32 |    160   |   64  | 64   |    128    |  64 | 64  |    0     |  0   |
                                  >---------------<           >-----------<          >--------------<           >-----------<
            */
            // psyncA
            mstore(pSyncA, shr(96, mload(add(_payload, 0x40))))
            mstore(add(pSyncA, 0x20), shr(128, mload(add(_payload, 0x54)))) // tokensForDove
            mstore(add(pSyncA, 0x40), shr(128, mload(add(_payload, 0x64)))) // earmarked
            mstore(add(pSyncA, 0x60), shr(128, mload(add(_payload, 0x74)))) // balance
            // psyncB
            mstore(pSyncB, shr(96, mload(add(_payload, 0x84)))) // token
            mstore(add(pSyncB, 0x20), shr(128, mload(add(_payload, 0x98))))
            mstore(add(pSyncB, 0x40), shr(128, mload(add(_payload, 0xA8))))
            mstore(add(pSyncB, 0x60), shr(128, mload(add(_payload, 0xB8))))
        }
    }

    /*##############################################################################################################################*/

    struct SyncToL2Payload {
        address token0;
        uint128 reserve0;
        uint128 reserve1;
    }

    function encodeSyncToL2(address token0, uint128 reserve0, uint128 reserve1) internal pure returns (bytes memory) {
        return abi.encode(SYNC_TO_L2, SyncToL2Payload(token0, reserve0, reserve1));
    }

    function decodeSyncToL2(bytes calldata _payload) internal pure returns (SyncToL2Payload memory) {
        (, SyncToL2Payload memory payload) = abi.decode(_payload, (uint256, SyncToL2Payload));
        return payload;
    }

    /*##############################################################################################################################*/

    struct VouchersBurnPayload {
        address user;
        uint128 amount0;
        uint128 amount1;
    }

    function encodeVouchersBurn(address user, uint128 amount0, uint128 amount1) internal pure returns (bytes memory) {
        return abi.encode(BURN_VOUCHERS, VouchersBurnPayload(user, amount0, amount1));
    }

    function decodeVouchersBurn(bytes calldata _payload) internal pure returns (VouchersBurnPayload memory) {
        (, VouchersBurnPayload memory vouchersBurnPayload) = abi.decode(_payload, (uint256, VouchersBurnPayload));
        return vouchersBurnPayload;
    }
}
