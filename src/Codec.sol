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
        uint256 tokensForDove; // tokens to send to Dove, aka vouchers held by pair burnt
        uint256 earmarkedAmount; // tokens to earmark aka vouchers
        uint256 pairBalance; // token balance of the pair
    }

    struct SyncerMetadata {
        uint64 syncerPercentage;
        address syncer;
    }

    function encodeSyncToL1(
        uint256 syncID,
        address L1Token0,
        uint256 pairVoucherBalance0,
        uint256 voucherDelta0, 
        uint256 balance0,
        address L1Token1,
        uint256 pairVoucherBalance1,
        uint256 voucherDelta1,
        uint256 balance1,
        address syncer,
        uint64 syncerPercentage
    ) internal pure returns (bytes memory payload) {
        assembly {
            payload := mload(0x40) // free mem ptr
            mstore(payload, 0x120) // store length
            /*
                fpacket is split into the following, left to right

                3 bits  | 16 bits | 14 bits | 160 bits |
                --------|---------|---------|----------|
                msgType | syncID  | syncer% | syncer |
            */
            let fpacket := shl(253, SYNC_TO_L1) // 3 bits
            fpacket := or(fpacket, shl(237, syncID)) // 16 bits
            fpacket := or(fpacket, shl(223, syncerPercentage)) // 14 bits
            fpacket := or(fpacket, shl(63, syncer)) // 160 bits
            mstore(add(payload, 0x20), fpacket) // 1 memory "slot" used so far
            mstore(add(payload, 0x40), L1Token0) // 1 memory "slot" used so far
            mstore(add(payload, 0x60), pairVoucherBalance0) // 2 memory "slots" used so far
            mstore(add(payload, 0x80), voucherDelta0) // 3 memory "slots" used so far
            mstore(add(payload, 0xA0), balance0) // 4 memory "slots" used so far
            mstore(add(payload, 0xC0), L1Token1) // 5 memory "slots" used so far
            mstore(add(payload, 0xE0), pairVoucherBalance1) // 6 memory "slots" used so far
            mstore(add(payload, 0x100), voucherDelta1) // 7 memory "slots" used so far
            mstore(add(payload, 0x120), balance1) // 8 memory "slots" used so far
            // update free mem ptr
            mstore(0x40, add(payload, 0x140))
        }
    }

    function decodeSyncToL1(bytes memory _payload)
        internal
        pure
        returns (uint256 syncID, SyncerMetadata memory sm, PartialSync memory pSyncA, PartialSync memory pSyncB)
    {
        assembly {
            let fpacket := mload(add(_payload, 0x20))
            //msgType := shr(253, fpacket)
            syncID := and(shr(237, fpacket), 0xFFFF)
            // syncer%
            mstore(sm, and(shr(223, fpacket), 0x3FFF))
            mstore(add(sm, 0x20), and(shr(63, fpacket), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
            // psyncA
            mstore(pSyncA, mload(add(_payload, 0x40)))
            mstore(add(pSyncA, 0x20), mload(add(_payload, 0x60)))
            mstore(add(pSyncA, 0x40), mload(add(_payload, 0x80)))
            mstore(add(pSyncA, 0x60), mload(add(_payload, 0xA0)))
            // psyncB
            mstore(pSyncB, mload(add(_payload, 0xC0)))
            mstore(add(pSyncB, 0x20), mload(add(_payload, 0xE0)))
            mstore(add(pSyncB, 0x40), mload(add(_payload, 0x100)))
            mstore(add(pSyncB, 0x60), mload(add(_payload, 0x120)))
        }
    }

    /*##############################################################################################################################*/

    struct SyncToL2Payload {
        address token0;
        uint256 reserve0;
        uint256 reserve1;
    }

    function encodeSyncToL2(address token0, uint256 reserve0, uint256 reserve1) internal pure returns (bytes memory) {
        return abi.encode(SYNC_TO_L2, SyncToL2Payload(token0, reserve0, reserve1));
    }

    function decodeSyncToL2(bytes calldata _payload) internal pure returns (SyncToL2Payload memory) {
        (, SyncToL2Payload memory payload) = abi.decode(_payload, (uint256, SyncToL2Payload));
        return payload;
    }

    /*##############################################################################################################################*/

    struct VouchersBurnPayload {
        address user;
        uint256 amount0;
        uint256 amount1;
    }

    function encodeVouchersBurn(address user, uint256 amount0, uint256 amount1) internal pure returns (bytes memory) {
        return abi.encode(BURN_VOUCHERS, VouchersBurnPayload(user, amount0, amount1));
    }

    function decodeVouchersBurn(bytes calldata _payload) internal pure returns (VouchersBurnPayload memory) {
        (, VouchersBurnPayload memory vouchersBurnPayload) = abi.decode(_payload, (uint256, VouchersBurnPayload));
        return vouchersBurnPayload;
    }
}
