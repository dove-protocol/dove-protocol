// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IL1Router {
    error Expired();
    error IdenticalAddress();
    error ZeroAddress();
    error InsuffcientAmountForQuote();
    error InsufficientLiquidity();
    error BelowMinimumAmount();
    error PairDoesNotExist();
    error InsufficientAmountA();
    error InsufficientAmountB();
    error TransferLiqToPairFailed();
    error CodeLength();
    error TransferFailed();

    struct route {
        address from;
        address to;
        bool stable;
    }
}
