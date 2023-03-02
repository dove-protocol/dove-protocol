// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity ^0.8.15;

// import "forge-std/Test.sol";
// import "forge-std/Vm.sol";
// import "forge-std/StdUtils.sol";
// import "forge-std/console.sol";

// import {Codec} from "src/Codec.sol";

// contract CodecTest is Test {

//     function testEncodeSyncToL1(
//         uint256 syncID,
//         address L1Token0,
//         uint256 pairVoucherBalance0,
//         uint256 voucherDelta0, 
//         uint256 balance0,
//         address L1Token1,
//         uint256 pairVoucherBalance1,
//         uint256 voucherDelta1,
//         uint256 balance1,
//         address syncer,
//         uint64 syncerPercentage
//     ) public {
//         syncID = vm.bound(syncID, 0, 3);
//         syncerPercentage = vm.bound(syncerPercentage, 0, 10000);
//     }

//         return abi.encode(
//             SYNC_TO_L1,
//             syncID,
//             SyncerMetadata(syncer, syncerPercentage),
//             PartialSync(L1Token0, pairVoucherBalance0, voucherDelta0, balance0),
//             PartialSync(L1Token1, pairVoucherBalance1, voucherDelta1, balance1)
//         );
//         assembly {
//             payload := mload(0x40) // free mem ptr
//             mstore(payload, 0x120) // store length
//             /*
//                 fpacket is split into the following, left to right

//                 3 bits  | 16 bits | 14 bits | 160 bits |
//                 --------|---------|---------|----------|
//                 msgType | syncID  | syncer% | syncer |
//             */
//             let fpacket := shl(253, msgType) // 3 bits
//             fpacket := or(fpacket, shl(237, syncID)) // 16 bits
//             fpacket := or(fpacket, shl(223, syncerPercentage)) // 14 bits
//             fpacket := or(fpacket, shl(63, syncer)) // 160 bits
//             mstore(add(payload, 0x20), fpacket) // 1 memory "slot" used so far
//             mstore(add(payload, 0x40), L1Token0) // 1 memory "slot" used so far
//             mstore(add(payload, 0x60), pairVoucherBalance0) // 2 memory "slots" used so far
//             mstore(add(payload, 0x80), voucherDelta0) // 3 memory "slots" used so far
//             mstore(add(payload, 0xA0), balance0) // 4 memory "slots" used so far
//             mstore(add(payload, 0xC0), L1Token1) // 5 memory "slots" used so far
//             mstore(add(payload, 0xE0), pairVoucherBalance1) // 6 memory "slots" used so far
//             mstore(add(payload, 0x100), voucherDelta1) // 7 memory "slots" used so far
//             mstore(add(payload, 0x120), balance1) // 8 memory "slots" used so far
//             // update free mem ptr
//             mstore(0x40, add(payload, 0x140))
//         }
// }