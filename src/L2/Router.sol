// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./Factory.sol";
import "./libraries/DoveLibrary.sol";
import "./Pair.sol";

contract Router {
    address public immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) external {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = DoveLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2 ? DoveLibrary.pairFor(factory, output, path[i + 2]) : _to;
            Pair(DoveLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
}
