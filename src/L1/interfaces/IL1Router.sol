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

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);
    function pairFor(address tokenA, address tokenB) external view returns (address pair);
    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB);
    function isPair(address pair) external view returns (bool);
    function quoteAddLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired)
        external
        view
        returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    function quoteRemoveLiquidity(address tokenA, address tokenB, uint256 liquidity)
        external
        view
        returns (uint256 amountA, uint256 amountB);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);
}
