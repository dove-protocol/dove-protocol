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

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);
    function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut) external view returns (uint256 amount);
    function getAmountsOut(uint256 amountIn, route[] memory routes) external view returns (uint256[] memory amounts);
    function isPair(address pair) external view returns (bool);
    function swapExactTokensForTokensSimple(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        route[] memory routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
