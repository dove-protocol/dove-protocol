// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./DoveBase.sol";

contract DoveLiquidityTest is DoveBase {
    function setUp() external {
        _setUp();
        vm.selectFork(L1_FORK_ID);
    }

    function testCannotWithdrawDuringLock() external {
        // move time to at least an epoch that is > 0
        vm.warp(block.timestamp + 16 days + 1);
        (uint256 amount0, uint256 amount1) =
            routerL1.quoteRemoveLiquidity(dove.token0(), dove.token1(), dove.balanceOf(address(this)));
        dove.approve(address(routerL1), type(uint256).max);
        address token0 = dove.token0();
        address token1 = dove.token1();
        uint256 balance = dove.balanceOf(address(this));
        vm.expectRevert("Liquidity locked");
        routerL1.removeLiquidity(token0, token1, balance, amount0, amount1, address(this), block.timestamp + 1);
    }

    function testCanRemoveLiquidityWhenUnlocked() external {
        // move time to at least an epoch that is > 0
        vm.warp(block.timestamp + 15 days);
        (uint256 amount0, uint256 amount1) =
            routerL1.quoteRemoveLiquidity(dove.token0(), dove.token1(), dove.balanceOf(address(this)));
        dove.approve(address(routerL1), type(uint256).max);
        routerL1.removeLiquidity(
            dove.token0(),
            dove.token1(),
            dove.balanceOf(address(this)),
            amount0,
            amount1,
            address(this),
            block.timestamp + 1
        );
    }
}