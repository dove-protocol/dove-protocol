// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IPair {
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint256 reserve0, uint256 reserve1);

    error InsufficientOutputAmount();
    error InsufficientLiquidity();
    error InvalidTo();
    error InsufficientInputAmount();
    error kInvariant();
    error NoVouchers();
    error MsgValueTooLow();
    error WrongOrigin();
    error NotDove();
}
