// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Dove} from "./Dove.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import "./interfaces/IL1Factory.sol";

contract L1Factory is IL1Factory, Ownable {
    /// @notice hyperlaneGasMaster address
    address public hyperlaneGasMaster;
    /// @notice hyperlane mailbox address
    address public mailbox;
    /// @notice stargate router address
    address public stargateRouter;
    /// @notice getPair[token0][token1] => pair address
    mapping(address => mapping(address => address)) public getPair;
    /// @notice address array containing all pairs
    address[] public allPairs;
    /// @notice pair address => bool, store address with bool flag true if it is created by this factory
    mapping(address => bool) public isPair;

    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/

    /// @notice constructor
    /// @param _hyperlaneGasMaster hyperlaneGasMaster address
    /// @param _mailbox hyperlane mailbox address
    /// @param _stargateRouter stargate router address
    constructor(address _hyperlaneGasMaster, address _mailbox, address _stargateRouter) {
        // deployer is the owner
        _initializeOwner(msg.sender);
        // set storage slots
        hyperlaneGasMaster = _hyperlaneGasMaster;
        mailbox = _mailbox;
        stargateRouter = _stargateRouter;
    }

    /*###############################################################
                            FACTORY
    ###############################################################*/

    /// @notice returns array length of allPairs[]
    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    /// @notice add trusted stargate bridge pair (remote, local)
    /// @param dove dove address
    /// @param chainId chain id
    /// @param remote remote address
    /// @param local local address
    function addStargateTrustedBridge(address dove, uint16 chainId, address remote, address local) onlyOwner external {
        Dove(dove).addStargateTrustedBridge(chainId, remote, local);
    }

    /// @notice add trusted hyperlane remote
    /// @param dove dove address
    /// @param origin origin hyperlane domain
    /// @param sender sender address
    function addTrustedRemote(address dove, uint32 origin, bytes32 sender) onlyOwner external {
        Dove(dove).addTrustedRemote(origin, sender);
    }

    /// @notice return pair code hash
    function pairCodeHash() external pure override returns (bytes32) {
        return keccak256(type(Dove).creationCode);
    }

    /// @notice Create a new LP Dove pool if it does not already exist
    /// @param tokenA token A address
    /// @param tokenB token B address
    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        if (tokenA == tokenB) revert IdenticalAddress();

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        if (token0 == address(0)) revert ZeroAddress();
        if (getPair[token0][token1] != address(0)) revert PairAlreadyExists();

        bytes32 salt = keccak256(abi.encodePacked(token0, token1, true));
        pair = address(
            new Dove{salt:salt}(
            token0,
            token1,
            hyperlaneGasMaster,
            mailbox
            )
        );
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        isPair[pair] = true;
        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}
