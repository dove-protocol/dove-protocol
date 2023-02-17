// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IL1Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    error OnlyPauser();
    error OnlyPendingPauser();
    error IdenticalAddress();
    error ZeroAddress();
    error PairAlreadyExists();

    function stargateRouter() external view returns (address);
    function isPair(address pair) external view returns (bool);
    function getPair(address tokenA, address token) external view returns (address);
    function allPairsLength() external view returns (uint256);
    function setPauser(address _pauser) external;
    function acceptPauser() external;
    function setPause(bool _state) external;
    function pairCodeHash() external pure returns (bytes32);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}
