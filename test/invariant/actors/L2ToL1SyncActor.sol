// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { DoveBase } from "../../DoveBase.sol";
import { Pair } from "../../../src/L2/Pair.sol";
import { Dove } from "../../../src/L1/Dove.sol";
import { L2Router } from "../../../src/L2/L2Router.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";

contract L2ToL1SyncActor is DoveBase {

    function syncReserves() external {
        pair.syncToL1{value: 800 ether}(
            200 ether, 
            200 ether
        );
    }

    function swapFrom0(uint256 _amountIn) external {
        uint256 boundedAmountIn = bound(_amountIn, 1, ERC20Mock(pair.token0()).balanceOf(address(this)));

        uint256 amountOut = routerL2.getAmountOut(boundedAmountIn, pair.token0(), pair.token1());

        routerL2.swapExactTokensForTokensSimple(
            boundedAmountIn,
            amountOut,
            pair.token0(),
            pair.token1(),
            address(this),
            block.timestamp + 1000
        );
    }

    function swapFrom1(uint256 _amountIn) external {
        uint256 boundedAmountIn = bound(_amountIn, 1, ERC20Mock(pair.token1()).balanceOf(address(this)));

        uint256 amountOut = routerL2.getAmountOut(boundedAmountIn, pair.token1(), pair.token0());

        routerL2.swapExactTokensForTokensSimple(
            boundedAmountIn,
            amountOut,
            pair.token1(),
            pair.token0(),
            address(this),
            block.timestamp + 1000
        );
    }
}