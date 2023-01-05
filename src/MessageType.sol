pragma solidity ^0.8.15;

library MessageType {
    uint256 public constant BURN_VOUCHERS = 1;
    uint256 public constant SYNC_TO_L1 = 2;
    uint256 public constant SYNC_TO_L2 = 3;
}
