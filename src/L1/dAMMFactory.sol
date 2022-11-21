pragma solidity ^0.8.15;


import "./interfaces/IdAMMFactory.sol";
import {dAMM as DAMM} from "./dAMM.sol";

contract dAMMFactory is IdAMMFactory {

    address public lzEndpoint;
    address public stargateRouter;
    address public admin;

    mapping(address => mapping(address => address)) public getdAMM;
    address[] public alldAMMs;

    constructor(address _lzEndpoint, address _stargateRouter) {
        admin = msg.sender;
        lzEndpoint = _lzEndpoint;
        stargateRouter = _stargateRouter;
    }

    function alldAMMsLength() external view override returns (uint) {
        return alldAMMs.length;
    }

    function createdAMM(address tokenA, address tokenB) external returns (address dAMM) {
        require(tokenA != tokenB, 'dAMM: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'dAMM: ZERO_ADDRESS');
        require(getdAMM[token0][token1] == address(0), 'dAMM: dAMM EXISTS');
        bytes memory bytecode = type(DAMM).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            dAMM := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        DAMM(dAMM).initialize(token0, token1);
        getdAMM[token0][token1] = dAMM;
        getdAMM[token1][token0] = dAMM; // populate mapping in the reverse direction
        alldAMMs.push(dAMM);
        emit dAMMCreated(token0, token1, dAMM, alldAMMs.length);
    }
}