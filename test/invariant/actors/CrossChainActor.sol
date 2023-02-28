// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { Vm } from "forge-std/Vm.sol";
import { TestBaseAssertions } from "../../TestBaseAssertions.sol";
import { Dove } from "../../../src/L1/Dove.sol";
import { L1Router } from "../../../src/L1/L1Router.sol";
import { Pair } from "../../../src/L2/Pair.sol";
import { L2Router } from "../../../src/L2/L2Router.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";

contract CrossChainActor is TestBaseAssertions {

    Dove public dove;
    L1Router public routerLiq;
    Pair public pair;
    L2Router public routerTrade;

    constructor (
        address _dove,
        address _routerL1,
        address _pair,
        address _routerL2
    ) {
        dove = Dove(_dove);
        routerLiq = L1Router(_routerL1);
        pair = Pair(_pair);
        routerTrade = L2Router(_routerL2);
    }

    function deposit(
        uint256 _amountADesired,
        uint256 _amountBDesired
    ) external {
        vm.selectFork(L1_FORK_ID);
        uint256 _maxA = ERC20Mock(dove.token0()).balanceOf(address(this));
        uint256 _maxB = ERC20Mock(dove.token0()).balanceOf(address(this));
        uint256 boundedDesiredA = constrictToRange(_amountADesired, 1001, _maxA);
        uint256 boundedDesiredB = constrictToRange(_amountBDesired, 1001, _maxB);

        (uint256 _amountMinA, uint256 _amountMinB, uint256 liquidity) = 
            routerLiq.quoteAddLiquidity(dove.token0(), dove.token1(), boundedDesiredA, boundedDesiredB);

        routerLiq.addLiquidity(
            dove.token0(),
            dove.token1(),
            boundedDesiredA,
            boundedDesiredB,
            _amountMinA,
            _amountMinB,
            address(this),
            type(uint256).max
        );
    }

    function withdraw(
        uint256 liquidity
    ) external {
        vm.selectFork(L2_FORK_ID);
        uint256 boundedLiquidity = constrictToRange(liquidity, 0, ERC20Mock(address(dove)).balanceOf(address(this)));

        (uint256 _amount0Min, uint256 _amount1Min) = 
            routerLiq.quoteRemoveLiquidity(dove.token0(), dove.token1(), boundedLiquidity);

        dove.approve(address(routerLiq), type(uint256).max);
        routerLiq.removeLiquidity(
            dove.token0(),
            dove.token1(),
            boundedLiquidity,
            _amount0Min,
            _amount1Min,
            address(this),
            block.timestamp + 1
        );
    }

    function swapFrom0(uint256 _amountIn) external {
        vm.selectFork(L2_FORK_ID);
        uint256 boundedAmountIn = constrictToRange(_amountIn, 1, ERC20Mock(pair.token0()).balanceOf(address(this)));

        uint256 amountOut = routerTrade.getAmountOut(boundedAmountIn, pair.token0(), pair.token1());

        routerTrade.swapExactTokensForTokensSimple(
            boundedAmountIn,
            amountOut,
            pair.token0(),
            pair.token1(),
            address(this),
            block.timestamp + 1000
        );
    }

    function swapFrom1(uint256 _amountIn) external {
        vm.selectFork(L2_FORK_ID);
        uint256 boundedAmountIn = constrictToRange(_amountIn, 1, ERC20Mock(pair.token1()).balanceOf(address(this)));

        uint256 amountOut = routerTrade.getAmountOut(boundedAmountIn, pair.token1(), pair.token0());

        routerTrade.swapExactTokensForTokensSimple(
            boundedAmountIn,
            amountOut,
            pair.token1(),
            pair.token0(),
            address(this),
            block.timestamp + 1000
        );
    }
}