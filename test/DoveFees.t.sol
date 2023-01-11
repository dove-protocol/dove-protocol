// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./DoveBase.sol";

contract DoveFeesTest is DoveBase {

    function setUp() external {
        _setUp();
    }

    function testFeesClaiming() external {

        vm.selectFork(L1_FORK_ID);
        // send the LP tokens before the sync so fees go to proper users
        uint256 balance = dove.balanceOf(address(this));
        dove.transfer(address(0xfab), balance / 3);
        dove.transfer(address(0xbaf), balance / 3);
        dove.transfer(address(0xbef), balance / 3);

        _syncToL2();
        vm.selectFork(L2_FORK_ID);
        _doSomeSwaps();
        _standardSyncToL1();


        (uint256 amount0, uint256 amount1) =
            routerL1.quoteRemoveLiquidity(dove.token0(), dove.token1(), dove.balanceOf(address(0xfab)));

        // remove liquidity
        vm.startBroadcast(address(0xfab));
        dove.approve(address(routerL1), dove.balanceOf(address(0xfab)));
        routerL1.removeLiquidity(
            dove.token0(),
            dove.token1(),
            dove.balanceOf(address(0xfab)),
            amount0,
            amount1,
            address(0xfab),
            block.timestamp + 1
        );
        vm.stopBroadcast();

        (amount0, amount1) = routerL1.quoteRemoveLiquidity(dove.token0(), dove.token1(), dove.balanceOf(address(0xbaf)));
        vm.startBroadcast(address(0xbaf));
        dove.approve(address(routerL1), dove.balanceOf(address(0xbaf)));
        routerL1.removeLiquidity(
            dove.token0(),
            dove.token1(),
            dove.balanceOf(address(0xbaf)),
            amount0,
            amount1,
            address(0xbaf),
            block.timestamp + 1
        );
        vm.stopBroadcast();

        (amount0, amount1) = routerL1.quoteRemoveLiquidity(dove.token0(), dove.token1(), dove.balanceOf(address(0xbef)));
        vm.startBroadcast(address(0xbef));
        dove.approve(address(routerL1), dove.balanceOf(address(0xbef)));
        routerL1.removeLiquidity(
            dove.token0(),
            dove.token1(),
            dove.balanceOf(address(0xbef)),
            amount0,
            amount1,
            address(0xbef),
            block.timestamp + 1
        );
        vm.stopBroadcast();

        assertTrue(L1Token0.balanceOf(address(0xfab)) > initialLiquidity0 / 3);
        assertTrue(L1Token0.balanceOf(address(0xbaf)) > initialLiquidity0 / 3);
        assertTrue(L1Token0.balanceOf(address(0xbef)) > initialLiquidity0 / 3);
        assertTrue(L1Token1.balanceOf(address(0xfab)) > initialLiquidity1 / 3);
        assertTrue(L1Token1.balanceOf(address(0xbaf)) > initialLiquidity1 / 3);
        assertTrue(L1Token1.balanceOf(address(0xbef)) > initialLiquidity1 / 3);
    }

    function testNoFeesIfAddLiquidityAfterSync() external {
        _syncToL2();
        vm.selectFork(L2_FORK_ID);
        _doSomeSwaps();
        _standardSyncToL1();

        (uint256 toAdd0, uint256 toAdd1,) =
            routerL1.quoteAddLiquidity(address(L1Token0), address(L1Token1), initialLiquidity0, initialLiquidity1); // 10M of each

        L1Token0.transfer(address(0xfefe), toAdd0);
        L1Token1.transfer(address(0xfefe), toAdd1);

        vm.startBroadcast(address(0xfefe));
        L1Token0.approve(address(routerL1), type(uint256).max);
        L1Token1.approve(address(routerL1), type(uint256).max);
        routerL1.addLiquidity(
            address(L1Token0),
            address(L1Token1),
            initialLiquidity0,
            initialLiquidity1,
            toAdd0,
            toAdd1,
            address(0xfefe),
            type(uint256).max
        );
        vm.stopBroadcast();
        
        dove.claimFeesFor(address(0xfefe));

        assertEq(L1Token0.balanceOf(address(0xfefe)), 0);
        assertEq(L1Token1.balanceOf(address(0xfefe)), 0);
    }

    function testAdjustedFeesOnLPTransfer() external {
        
        vm.selectFork(L1_FORK_ID);
        // send the LP tokens before the sync so fees go to proper users
        uint256 balance = dove.balanceOf(address(this));
        dove.transfer(address(0xfab), balance / 3);
        dove.transfer(address(0xbaf), balance / 3);
        dove.transfer(address(0xbef), balance / 3);

        _syncToL2();
        vm.selectFork(L2_FORK_ID);
        _doSomeSwaps();
        _standardSyncToL1();

        vm.selectFork(L1_FORK_ID);
        uint256 expectedFees0 = L1Token0.balanceOf(address(dove.feesDistributor())) / 3;

        vm.startBroadcast(address(0xfab));
        dove.transfer(address(0xfafa), dove.balanceOf(address(0xfab)));
        vm.stopBroadcast();

        // equivalent to 1e-9 error tolerance
        assertApproxEqAbs(dove.claimable0(address(0xfab)), expectedFees0, 10**9);
        assertEq(dove.claimable0(address(0xfafa)), 0);
    }
}