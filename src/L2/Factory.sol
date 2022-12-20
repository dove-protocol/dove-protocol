// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./Pair.sol";
import "./interfaces/IFactory.sol";

contract Factory is IFactory {
    address public feeTo;
    address public feeToSetter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    address public gasMaster;
    address public mailbox;
    address public stargateRouter;
    address public L1Target;
    uint16 public destChainId;
    uint32 public destDomain;

    constructor(
        address _feeToSetter,
        address _gasMaster,
        address _mailbox,
        address _stargateRouter,
        address _L1Target,
        uint16 _destChainId,
        uint32 _destDomain
    ) public {
        feeToSetter = _feeToSetter;
        gasMaster = _gasMaster;
        mailbox = _mailbox;
        stargateRouter = _stargateRouter;
        L1Target = _L1Target;
        destChainId = _destChainId;
        destDomain = _destDomain;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(
        address tokenA,
        address tokenB,
        address L1TokenA,
        address L1TokenB
    ) external returns (address pair) {
        require(tokenA != tokenB, "Factory: IDENTICAL_ADDRESSES");
        // sort tokens
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (address L1Token0, address L1Token1) = L1TokenA < L1TokenB ? (L1TokenA, L1TokenB) : (L1TokenB, L1TokenA);

        require(token0 != address(0), "Factory: ZERO_ADDRESS");
        require(L1Token0 != address(0), "Factory: ZERO_ADDRESS_ORIGIN");
        // check if pair exists
        address pairAddress = getPair[token0][token1];
        require(pairAddress == address(0), "Factory: PAIR_EXISTS"); // single check is sufficient
        bytes memory bytecode = abi.encodePacked(
            type(Pair).creationCode,
            abi.encode(
                token0,
                L1Token0,
                token1,
                L1Token1,
                gasMaster,
                mailbox,
                stargateRouter,
                L1Target,
                destChainId,
                destDomain
            )
        );
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "UniswapV2: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}
