// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "solmate/auth/Owned.sol";
import "./interfaces/IL2Factory.sol";

import "./Pair.sol";

contract L2Factory is IL2Factory, Owned {
    /*###############################################################
                            STORAGE
    ###############################################################*/
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    mapping(address => bool) public isPair;

    address public gasMaster;
    address public mailbox;
    address public stargateRouter;
    uint16 public destChainId;
    uint16 public voucherLimiter = 1000;
    uint32 public destDomain;

    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _gasMaster, address _mailbox, address _stargateRouter, uint16 _destChainId, uint32 _destDomain)
    Owned(msg.sender)
    public
    {
        gasMaster = _gasMaster;
        mailbox = _mailbox;
        stargateRouter = _stargateRouter;
        destChainId = _destChainId;
        destDomain = _destDomain;
    }

    /*###############################################################
                            Factory
    ###############################################################*/
    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function pairCodeHash() external pure override returns (bytes32) {
        return keccak256(type(Pair).creationCode);
    }

    function createPair(
        address tokenA,
        address tokenB,
        SGConfig calldata sgConfig,
        address L1TokenA,
        address L1TokenB,
        address L1Target
    ) external override returns (address pair) {
        if (tokenA == tokenB) revert IdenticalAddress();

        // sort tokens
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (address L1Token0, address L1Token1) = token0 == tokenA ? (L1TokenA, L1TokenB) : (L1TokenB, L1TokenA);

        if ((token0 == address(0) || token1 == address(0))) revert ZeroAddress();
        if ((L1Token0 == address(0) || L1Token1 == address(0))) revert ZeroAddressOrigin();
        if (getPair[token0][token1] != address(0)) revert PairExists();

        bytes32 salt = keccak256(abi.encodePacked(token0, L1Token0, token1, L1Token1, gasMaster, mailbox, L1Target));
        // shitty design, should remove gasMaster,sgRouter, destChainId and destDomain from constructor
        // should query factory
        pair = address(
            new Pair{salt: salt}(
                token0,
                L1Token0,
                token1,
                L1Token1,
                sgConfig,
                gasMaster,
                mailbox,
                L1Target
            )
        );

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        isPair[pair] = true;
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setVoucherLimiter(uint16 _voucherLimiter) external onlyOwner {
        if (_voucherLimiter > 10000) revert NewVoucherLimiterOutOfRange();
        voucherLimiter = _voucherLimiter;
    }
}
