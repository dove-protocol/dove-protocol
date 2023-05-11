// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Pair} from "./Pair.sol";
import {L2Factory} from "./L2Factory.sol";

import "./interfaces/IL2Router.sol";

contract L2Router is IL2Router {
    /// @notice factory
    L2Factory public immutable factory;
    /// @notice pair code hash
    bytes32 immutable pairCodeHash;

    /// @notice modifier to ensure deadline is not passed
    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "BaseV1Router: EXPIRED");
        _;
    }

    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/

    /// @notice constructor
    /// @param _factory address of factory
    constructor(address _factory) {
        // set storage
        factory = L2Factory(_factory);
        pairCodeHash = factory.pairCodeHash();
    }

    /*###############################################################
                            ROUTER
    ###############################################################*/

    /// @notice sort tokens
    function sortTokens(address tokenA, address tokenB) public pure override returns (address token0, address token1) {
        // revert if identical addresses
        if (tokenA == tokenB) revert IdenticalAddress();
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // revert if zero address
        if (token0 == address(0)) revert ZeroAddress();
    }

    /// @notice performs getAmountOut calculation on single pair
    /// @param amountIn amount of token to swap
    /// @param tokenIn address of token to swap
    /// @param tokenOut address of token to receive
    function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut)
        external
        view
        override
        returns (uint256 amount)
    {
        address pair = factory.getPair(tokenIn, tokenOut);
        // calculate amount out, then return
        amount = Pair(pair).getAmountOut(amountIn, tokenIn);
    }

    /// @notice performs chained getAmountOut calculations on any number of pairs
    /// @param amountIn amount of token to swap
    /// @param routes array of route structs
    function getAmountsOut(uint256 amountIn, route[] memory routes)
        public
        view
        override
        returns (uint256[] memory amounts)
    {
        // routes must be greater than 1
        if (routes.length < 1) revert InvalidPath();
        // initialize amounts array
        amounts = new uint[](routes.length+1);
        // set first amount
        amounts[0] = amountIn;
        // iterate through routes, getAmountOut for each
        for (uint256 i = 0; i < routes.length; i++) {
            address pair = factory.getPair(routes[i].from, routes[i].to);
            if (factory.isPair(pair)) {
                amounts[i + 1] = Pair(pair).getAmountOut(amounts[i], routes[i].from);
            }
        }
    }

    /// @notice check if "pair" is a pair
    /// @param pair address of pair
    function isPair(address pair) external view override returns (bool) {
        return factory.isPair(pair);
    }

    /// @notice performs swap given amounts, routes and to address
    ///         requires the initial amount to have already been sent to the first pair
    /// @param amounts array of amounts to swap
    /// @param routes array of route structs
    /// @param _to address to send swapped tokens to
    /// @dev used by swapExactTokensForTokensSimple() & swapExactTokensForTokens()
    function _swap(uint256[] memory amounts, route[] memory routes, address _to) internal virtual {
        // iterate through routes, swap for each
        for (uint256 i = 0; i < routes.length; i++) {
            (address token0,) = sortTokens(routes[i].from, routes[i].to);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                routes[i].from == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < routes.length - 1 ? factory.getPair(routes[i + 1].from, routes[i + 1].to) : _to;
            Pair(factory.getPair(routes[i].from, routes[i].to)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    /// @notice performs swap across one pair
    /// @param amountIn amount of token to swap
    /// @param amountOutMin minimum amount of token to receive
    /// @param tokenFrom address of token to swap
    /// @param tokenTo address of token to receive
    /// @param to address to send swapped tokens to
    /// @param deadline timestamp of deadline
    function swapExactTokensForTokensSimple(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenFrom,
        address tokenTo,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        // load single route for one pair
        route[] memory routes = new route[](1);
        routes[0].from = tokenFrom;
        routes[0].to = tokenTo;
        // get amount out quote
        amounts = getAmountsOut(amountIn, routes);
        // if get amount out returns less than minimum amount out, revert
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();
        // make transfer for tokenFrom to tokenTo using pair
        _safeTransferFrom(routes[0].from, msg.sender, factory.getPair(routes[0].from, routes[0].to), amounts[0]);
        _swap(amounts, routes, to);
    }

    /// @notice performs swap across multiple pairs
    /// @param amountIn amount of token to swap
    /// @param amountOutMin minimum amount of token to receive
    /// @param routes array of route structs
    /// @param to address to send swapped tokens to
    /// @param deadline timestamp of deadline
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        route[] calldata routes,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256[] memory amounts) {
        // get amount out quote
        amounts = getAmountsOut(amountIn, routes);
        // if get amount out returns less than minimum amount out, revert
        if (amounts[amounts.length - 1] < amountOutMin) revert InsufficientOutputAmount();
        // make transfer for tokenFrom to tokenTo using pair
        _safeTransferFrom(routes[0].from, msg.sender, factory.getPair(routes[0].from, routes[0].to), amounts[0]);
        _swap(amounts, routes, to);
    }

    /// @notice transfer "value" of "token" to "to" address
    /// @param token address of token to transfer
    /// @param to address to send tokens to
    /// @param value amount of token to transfer
    function _safeTransfer(address token, address to, uint256 value) internal {
        if (!(token.code.length > 0)) revert CodeLength();
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(ERC20.transfer.selector, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert TransferFailed();
    }

    /// @notice transfer "value" of "token" from "from" to "to" address
    /// @param token address of token to transfer
    /// @param from address to send tokens from
    /// @param to address to send tokens to
    /// @param value amount of token to transfer
    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        if (!(token.code.length > 0)) revert CodeLength();
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(ERC20.transferFrom.selector, from, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert TransferFailed();
    }
}
