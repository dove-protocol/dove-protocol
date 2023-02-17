// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IL2Router {
    error Expired();
    error IdenticalAddress();
    error ZeroAddress();
    error InvalidPath();
    error InsufficientOutputAmount();
    error CodeLength();
    error TransferFailed();

    struct route {
        address from;
        address to;
    }
}
