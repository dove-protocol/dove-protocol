// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./Pair.sol";

contract L2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    mapping(address => bool) public isPair;

    address public gasMaster;
    address public mailbox;
    address public stargateRouter;
    uint16 public destChainId;
    uint32 public destDomain;

    /// @param _gasMaster Address of the Hyperlane gas master contract.
    /// @param _mailbox Address of the Hyperlane mailbox contract.
    /// @param _stargateRouter Address of the Stargate router contract.
    /// @param _destChainId Destination chain ID.
    /// @param _destDomain Destination domain ID. (https://docs.hyperlane.xyz/hyperlane-docs-1/developers-faq-and-troubleshooting/domains)
    constructor(address _gasMaster, address _mailbox, address _stargateRouter, uint16 _destChainId, uint32 _destDomain)
        public
    {
        gasMaster = _gasMaster;
        mailbox = _mailbox;
        stargateRouter = _stargateRouter;
        destChainId = _destChainId;
        destDomain = _destDomain;
    }

    /// @notice Returns the number of pairs in the factory.
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /// @notice Returns the creation code hash of the pair contract.
    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(Pair).creationCode);
    }

    /// @notice Creates a new pair contract and registers it in the factory.
    /// @param tokenA Address of the first token.
    /// @param tokenB Address of the second token.
    /// @param L1TokenA Address of the first token on L1.
    /// @param L1TokenB Address of the second token on L1.
    /// @param L1Target Address of the L1 target contract.
    function createPair(address tokenA, address tokenB, address L1TokenA, address L1TokenB, address L1Target)
        external
        returns (address pair)
    {
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
                gasMaster,
                mailbox,
                stargateRouter,
                L1Target,
                destChainId,
                destDomain
            )
        );
        // shitty design, should remove gasMaster,sgRouter, destChainId and destDomain from constructor
        // should query factory
        pair = address(
            new Pair{salt:salt}(
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

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        isPair[pair] = true;
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}
