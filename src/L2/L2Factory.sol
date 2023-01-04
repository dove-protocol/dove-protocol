// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./Pair.sol";

contract L2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    mapping(address => bool) public isPair;

    mapping(address => mapping(address => address)) public getL1Pair;

    address public gasMaster;
    address public mailbox;
    address public stargateRouter;
    uint16 public destChainId;
    uint32 public destDomain;

    constructor(
        address _gasMaster,
        address _mailbox,
        address _stargateRouter,
        uint16 _destChainId,
        uint32 _destDomain
    ) public {
        gasMaster = _gasMaster;
        mailbox = _mailbox;
        stargateRouter = _stargateRouter;
        destChainId = _destChainId;
        destDomain = _destDomain;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(Pair).creationCode);
    }

    function createPair(
        address tokenA,
        address tokenB,
        uint16 srcPoolId0,
        uint16 srcPoolId1,
        uint16 dstPoolId0,
        uint16 dstPoolId1,
        address L1TokenA,
        address L1TokenB,
        address L1Target
    ) external returns (address pair) {
        require(tokenA != tokenB, "Factory: IDENTICAL_ADDRESSES");
        // sort tokens
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (address L1Token0, address L1Token1) = token0 == tokenA ? (L1TokenA, L1TokenB) : (L1TokenB, L1TokenA);
        require(token0 != address(0) && token1 != address(0), "Factory: ZERO_ADDRESS");
        require(L1Token0 != address(0) && L1Token1 != address(0), "Factory: ZERO_ADDRESS_ORIGIN");
        // check if pair exists
        address pairAddress = getPair[token0][token1];
        require(pairAddress == address(0), "Factory: PAIR_EXISTS"); // single check is sufficient
        bytes32 salt = keccak256(
            abi.encodePacked(
                token0,
                L1Token0,
                token1,
                L1Token1,
                srcPoolId0,
                srcPoolId1,
                dstPoolId0,
                dstPoolId1,
                gasMaster,
                mailbox,
                L1Target
            )
        );
        // shitty design, should remove gasMaster,sgRouter, destChainId and destDomain from constructor
        // should query factory
        pair = address(
            new Pair{salt: salt}(
                token0,
                L1Token0,
                token1,
                L1Token1,
                srcPoolId0,
                srcPoolId1,
                dstPoolId0,
                dstPoolId1,
                gasMaster,
                mailbox,
                L1Target
            )
        );

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        getL1Pair[token0][token1] = L1Target;
        getL1Pair[token1][token0] = L1Target; // populate mapping in the reverse direction
        allPairs.push(pair);
        isPair[pair] = true;
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}
