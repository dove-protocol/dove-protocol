// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Pair} from "./Pair.sol";
import {L2Factory} from "./L2Factory.sol";

contract L2Router {
    struct Route {
        address from;
        address to;
    }

    L2Factory public immutable factory;
    bytes32 immutable pairCodeHash;

    /// @notice Prevents a function from being called after a deadline.
    /// @param deadline Deadline timestamp.
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "BaseV1Router: EXPIRED");
        _;
    }

    /// @param _factory Address of the L2Factory contract.
    constructor(address _factory) {
        factory = L2Factory(_factory);
        pairCodeHash = factory.pairCodeHash();
    }

    /// @notice Sorts token pairs based on their addresses for consistent ordering.
    /// @param tokenA Address of the first token.
    /// @param tokenB Address of the second token.
    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        require(tokenA != tokenB, "BaseV1Router: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "BaseV1Router: ZERO_ADDRESS");
    }

    /// @notice Performs getAmountOut calculations given a pair and an amountIn.
    /// @param amountIn Amount of tokenIn to swap.
    /// @param tokenIn Address of the token to swap from.
    /// @param tokenOut Address of the token to swap to.
    function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut) external view returns (uint256 amount) {
        address pair = factory.getPair(tokenIn, tokenOut);
        amount = Pair(pair).getAmountOut(amountIn, tokenIn);
    }

    /// @notice Performs chained getAmountOut calculations on any number of pairs.
    /// @param amountIn Amount of tokenIn to swap.
    /// @param routes An array of route structs, each containing a token pair.
    function getAmountsOut(uint256 amountIn, Route[] memory routes) public view returns (uint256[] memory amounts) {
        require(routes.length >= 1, "BaseV1Router: INVALID_PATH");
        amounts = new uint[](routes.length+1);
        amounts[0] = amountIn;
        for (uint256 i = 0; i < routes.length; i++) {
            address pair = factory.getPair(routes[i].from, routes[i].to);
            if (factory.isPair(pair)) {
                amounts[i + 1] = Pair(pair).getAmountOut(amounts[i], routes[i].from);
            }
        }
    }

    /// @notice Checks if provided address is a registered pair.
    /// @param pair Address to check.
    function isPair(address pair) external view returns (bool) {
        return factory.isPair(pair);
    }

    /// @notice Swap tokens for an exact amount of tokens given a pair.
    /// @param amountIn Amount of tokenIn to swap.
    /// @param amountOutMin Minimum amount of tokenOut to receive.
    /// @param tokenFrom Address of the token to swap from.
    /// @param tokenTo Address of the token to swap to.
    /// @param to Address to send the output tokens to.
    /// @param deadline Time at which this transaction must be mined.
    function swapExactTokensForTokensSimple(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenFrom,
        address tokenTo,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        Route[] memory routes = new route[](1);
        routes[0].from = tokenFrom;
        routes[0].to = tokenTo;
        amounts = getAmountsOut(amountIn, routes);
        require(amounts[amounts.length - 1] >= amountOutMin, "BaseV1Router: INSUFFICIENT_OUTPUT_AMOUNT");
        _safeTransferFrom(routes[0].from, msg.sender, factory.getPair(routes[0].from, routes[0].to), amounts[0]);
        _swap(amounts, routes, to);
    }

    /// @notice Swap tokens for an exact amount of tokens given a path
    /// @param amountIn Amount of tokenIn to swap.
    /// @param amountOutMin Minimum amount of tokenOut to receive.
    /// @param routes An array of route structs, each containing a token pair.
    /// @param to Address to send the output tokens to.
    /// @param deadline Time at which this transaction must be mined.
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Route[] calldata routes,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsOut(amountIn, routes);
        require(amounts[amounts.length - 1] >= amountOutMin, "BaseV1Router: INSUFFICIENT_OUTPUT_AMOUNT");
        _safeTransferFrom(routes[0].from, msg.sender, factory.getPair(routes[0].from, routes[0].to), amounts[0]);
        _swap(amounts, routes, to);
    }

    /// @dev Requires initial amount to be sent to the first pair in the path
    function _swap(uint256[] memory amounts, route[] memory routes, address _to) internal virtual {
        for (uint256 i = 0; i < routes.length; i++) {
            (address token0,) = sortTokens(routes[i].from, routes[i].to);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                routes[i].from == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < routes.length - 1 ? factory.getPair(routes[i + 1].from, routes[i + 1].to) : _to;
            Pair(factory.getPair(routes[i].from, routes[i].to)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(ERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(ERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
}
