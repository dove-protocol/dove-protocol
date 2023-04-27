// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Dove} from "./Dove.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import "./interfaces/IL1Factory.sol";

contract L1Factory is IL1Factory, Ownable {
    address public hyperlaneGasMaster;
    address public mailbox;
    address public stargateRouter;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    mapping(address => bool) public isPair; // simplified check if its a pair, given that `stable` flag might not be available in peripherals

    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(address _hyperlaneGasMaster, address _mailbox, address _stargateRouter) {
        _initializeOwner(msg.sender);

        hyperlaneGasMaster = _hyperlaneGasMaster;
        mailbox = _mailbox;
        stargateRouter = _stargateRouter;
    }

    /*###############################################################
                            FACTORY
    ###############################################################*/
    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function addStargateTrustedBridge(address dove, uint16 chainId, address remote, address local) onlyOwner external {
        Dove(dove).addStargateTrustedBridge(chainId, remote, local);
    }

    function addTrustedRemote(address dove, uint32 origin, bytes32 sender) onlyOwner external {
        Dove(dove).addTrustedRemote(origin, sender);
    }

    function pairCodeHash() external pure override returns (bytes32) {
        return keccak256(type(Dove).creationCode);
    }

    // Create a new LP pair if it does not already exist
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
