// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB, address L1TokenA, address L1TokenB)
        external
        returns (address pair);
}
