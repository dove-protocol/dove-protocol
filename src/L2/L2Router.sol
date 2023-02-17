// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Pair} from "./Pair.sol";
import {L2Factory} from "./L2Factory.sol";

import "./interfaces/IL2Router.sol";

contract L2Router is IL2Router {
    L2Factory public immutable factory;
    bytes32 immutable pairCodeHash;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "BaseV1Router: EXPIRED");
        _;
    }

    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _factory) {
        factory = L2Factory(_factory);
        pairCodeHash = factory.pairCodeHash();
    }

    /*###############################################################
                            ROUTER
    ###############################################################*/
    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        if (tokenA == tokenB) revert IdenticalAddress();

        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut) external view returns (uint256 amount) {
        address pair = factory.getPair(tokenIn, tokenOut);
        amount = Pair(pair).getAmountOut(amountIn, tokenIn);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint256 amountIn, route[] memory routes) public view returns (uint256[] memory amounts) {
        if (routes.length < 1) revert InvalidPath();

        amounts = new uint[](routes.length+1);
        amounts[0] = amountIn;
        for (uint256 i = 0; i < routes.length; i++) {
            address pair = factory.getPair(routes[i].from, routes[i].to);
            if (factory.isPair(pair)) {
                amounts[i + 1] = Pair(pair).getAmountOut(amounts[i], routes[i].from);
            }
        }
    }

    function isPair(address pair) external view returns (bool) {
        return factory.isPair(pair);
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
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

    function swapExactTokensForTokensSimple(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenFrom,
        address tokenTo,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        route[] memory routes = new route[](1);
        routes[0].from = tokenFrom;
        routes[0].to = tokenTo;
        amounts = getAmountsOut(amountIn, routes);
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();

        _safeTransferFrom(routes[0].from, msg.sender, factory.getPair(routes[0].from, routes[0].to), amounts[0]);
        _swap(amounts, routes, to);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        route[] calldata routes,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsOut(amountIn, routes);
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();

        _safeTransferFrom(routes[0].from, msg.sender, factory.getPair(routes[0].from, routes[0].to), amounts[0]);
        _swap(amounts, routes, to);
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        if (!(token.code.length > 0)) revert CodeLength();

        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(ERC20.transfer.selector, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert TransferFailed();
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        if (!(token.code.length > 0)) revert CodeLength();

        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(ERC20.transferFrom.selector, from, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert TransferFailed();
    }
}
