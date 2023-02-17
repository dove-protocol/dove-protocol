// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IL1Factory {
    function stargateRouter() external view returns (address);
    function allPairsLength() external view returns (uint256);
    function isPair(address pair) external view returns (bool);
    function pairCodeHash() external pure returns (bytes32);
    function getPair(address tokenA, address token) external view returns (address);
}
