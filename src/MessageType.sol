pragma solidity ^0.8.15;

library MessageType {
    /// @notice Burns vouchers for L1 tokens and optionally L2 if liquidity is available.
    uint256 public constant BURN_VOUCHERS = 1;
    /// @notice Syncs the L2 state to the L1 state.
    uint256 public constant SYNC_TO_L1 = 2;
    /// @notice Syncs the L1 state to the L2 state.
    uint256 public constant SYNC_TO_L2 = 3;
}
