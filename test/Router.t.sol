// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console2.sol";

import {Pair} from "src/L2/Pair.sol";
import {Factory} from "src/L2/Factory.sol";
import {Router} from "src/L2/Router.sol";
import {TypeCasts} from "src/hyperlane/TypeCasts.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";

/// Only test AMM logic, nothing related to cross-chain.
contract RouterTest is Test {
    ERC20Mock token0L1;
    ERC20Mock token1L1;

    Router router;
    Factory factory;
    Pair pair;

    ERC20Mock token0L2;
    ERC20Mock token1L2;

    uint256 reserve0 = 10**6 * 10**6;
    uint256 reserve1 = 10**6 * 10**18;

    address fees = address(0xfee);

    function setUp() external {
        token0L1 = new ERC20Mock("USDC", "USDC", 6); // USDC
        token1L1 = new ERC20Mock("DAI", "DAI", 18); // DAI

        token0L2 = new ERC20Mock("USDC", "USDC", 6); // USDC
        token1L2 = new ERC20Mock("DAI", "DAI", 18); // DAI

        factory = new Factory(fees, address(0), address(0), address(0), address(this), 0, 0);
        pair = Pair(factory.createPair(address(token0L2), address(token1L2), address(token0L2), address(token1L2)));

        token0L2.approve(address(pair), type(uint256).max);
        token1L2.approve(address(pair), type(uint256).max);

        token0L2.mint(address(this), 1000 * 10**6);
        token1L2.mint(address(this), 1000 * 10**18);

        pair.handle(0, TypeCasts.addressToBytes32(address(this)), abi.encode(reserve0, reserve1));
    }

    function testSingleSwap() external {
        uint256 amount0In = 5000 * 10**6;
        uint256 amount1Out = pair.getAmountOut(amount0In, address(token0L2));

        pair.swap(0, amount1Out, address(0xBEEF), "");
        console2.log("Beef got amount1Out = ", token1L2.balanceOf(address(0xBEEF)));
        console2.log("0xFE has token0 fees = ", token0L2.balanceOf(fees));
    }

    receive() external payable {}
}
