// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "solmate/auth/Owned.sol";
import "./interfaces/IL2Factory.sol";
import "./Pair.sol";

contract L2Factory is IL2Factory, Owned {
    /*###############################################################
                            STORAGE
    ###############################################################*/
    /// @notice getPair[token0][token1] => pair
    mapping(address => mapping(address => address)) public getPair;
    /// @notice array storing all pair addresses
    address[] public allPairs;
    // @notice isPair[pair] => bool, check if address is pair
    mapping(address => bool) public isPair;
    /// @notice address constants
    // hyperlane gas master on L2 this pair is deployed on
    address public gasMaster;
    // hyperlane mailbox on this L2 this pair is deployed on
    address public mailbox;
    // stargate router on L2 this pair is deployed on
    address public stargateRouter;
    // chain id of L1
    uint16 public destChainId;
    // voucher limiter
    uint16 public voucherLimiter = 1000;
    // hyperlane domain of L1
    uint32 public destDomain;
    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/

    /// @notice constructor
    /// @param _gasMaster address of gasMaster
    /// @param _mailbox address of mailbox
    /// @param _stargateRouter address of stargateRouter
    /// @param _destChainId chain id of L1
    /// @param _destDomain hyperlane domain of L1
    constructor(address _gasMaster, address _mailbox, address _stargateRouter, uint16 _destChainId, uint32 _destDomain)
    Owned(msg.sender)
    public
    {
        // set storage
        gasMaster = _gasMaster;
        mailbox = _mailbox;
        stargateRouter = _stargateRouter;
        destChainId = _destChainId;
        destDomain = _destDomain;
    }

    /*###############################################################
                            Factory
    ###############################################################*/

    /// @notice return length of allPairs array
    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    /// @notice return pair code hash
    function pairCodeHash() external pure override returns (bytes32) {
        return keccak256(type(Pair).creationCode);
    }

    /// @notice create pair on L2Factory's L2 chain
    /// @param tokenA tokenA address
    /// @param tokenB tokenB address
    /// @param sgConfig SGConfig struct, configuration of tokens in the stargate pool
    /// @param L1TokenA tokenA address on L1
    /// @param L1TokenB tokenB address on L1
    /// @param L1Target target address on L1
    function createPair(
        address tokenA,
        address tokenB,
        SGConfig calldata sgConfig,
        address L1TokenA,
        address L1TokenB,
        address L1Target
    ) external override returns (address pair) {
        // revert if tokenA = tokenB
        if (tokenA == tokenB) revert IdenticalAddress();
        // sort tokens
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (address L1Token0, address L1Token1) = token0 == tokenA ? (L1TokenA, L1TokenB) : (L1TokenB, L1TokenA);
        // revert if token0 or token1 is zero address
        if ((token0 == address(0) || token1 == address(0))) revert ZeroAddress();
        // revert if origin tokens on L1 are zero address
        if ((L1Token0 == address(0) || L1Token1 == address(0))) revert ZeroAddressOrigin();
        //revert if pair already exists
        if (getPair[token0][token1] != address(0)) revert PairExists();
        // compute address salt for pair creation
        bytes32 salt = keccak256(abi.encodePacked(token0, L1Token0, token1, L1Token1, gasMaster, mailbox, L1Target));
        // shitty design, should remove gasMaster,sgRouter, destChainId and destDomain from constructor
        // should query factory
        // create pair
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
        // add pair to mappings
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
