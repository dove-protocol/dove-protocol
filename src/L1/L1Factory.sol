// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Dove} from "./Dove.sol";

contract L1Factory {
    address public hyperlaneGasMaster;
    address public mailbox;
    address public sgRouter;

    bool public isPaused;
    address public pauser;
    address public pendingPauser;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    mapping(address => bool) public isPair; // simplified check if its a pair, given that `stable` flag might not be available in peripherals

    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    constructor(address _hyperlaneGasMaster, address _mailbox, address _sgRouter) {
        pauser = msg.sender;
        isPaused = false;

        hyperlaneGasMaster = _hyperlaneGasMaster;
        mailbox = _mailbox;
        sgRouter = _sgRouter;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function setPauser(address _pauser) external {
        require(msg.sender == pauser);
        pendingPauser = _pauser;
    }

    function acceptPauser() external {
        require(msg.sender == pendingPauser);
        pauser = pendingPauser;
    }

    function setPause(bool _state) external {
        require(msg.sender == pauser);
        isPaused = _state;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(Dove).creationCode);
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "IA"); // BaseV1: IDENTICAL_ADDRESSES
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "ZA"); // BaseV1: ZERO_ADDRESS
        require(getPair[token0][token1] == address(0), "PE"); // BaseV1: PAIR_EXISTS - single check is sufficient
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, true));
        pair = address(
            new Dove{salt:salt}(
            token0,
            token1,
            hyperlaneGasMaster,
            mailbox,
            sgRouter
            )
        );
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        isPair[pair] = true;
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}