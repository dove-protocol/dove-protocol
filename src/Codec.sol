pragma solidity ^0.8.15;

library Codec {
    uint256 public constant BURN_VOUCHERS = 1;
    uint256 public constant SYNC_TO_L1 = 2;
    uint256 public constant SYNC_TO_L2 = 3;

    struct SyncToL1Payload {
        address token;
        uint256 tokensForDove; // tokens to send to Dove, aka vouchers held by pair burnt
        uint256 earmarkedAmount; // tokens to earmark aka vouchers
        uint256 pairBalance; // token balance of the pair
    }

    function encodeSyncToL1(
        uint256 syncID,
        address L1Token,
        uint256 pairVoucherBalance,
        uint256 voucherDelta,
        uint256 balance
    ) internal pure returns (bytes memory) {
        return abi.encode(SYNC_TO_L1, syncID, SyncToL1Payload(L1Token, pairVoucherBalance, voucherDelta, balance));
    }

    function decodeSyncToL1(bytes calldata _payload) internal pure returns (uint256, SyncToL1Payload memory) {
        (, uint256 syncID, SyncToL1Payload memory payload) = abi.decode(_payload, (uint256, uint256, SyncToL1Payload));
        return (syncID, payload);
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
