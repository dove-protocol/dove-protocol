// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/console.sol";
import "./DoveBaseMulti.sol";

contract DoveMultiSyncTest is DoveBaseMulti {
    function setUp() external {
        _setUp();
    }

    function testSyncsWithYeets() external {
        vm.selectFork(L1_FORK_ID);
        uint256 initialR0 = dove.reserve0();
        uint256 initialR1 = dove.reserve1();
        uint256 k = _k(initialR0, initialR1);

        _syncToL2(L2_FORK_ID);
        _syncToL2(L3_FORK_ID);
        _doSomeSwaps();
        // no usdc to swap back
        _yeetVouchers(address(0xbeef), 0, pair.voucher1().balanceOf(address(0xbeef)));
        _doSomeSwapsOnL3();
        // same exact state as on the first L2
        _yeetVouchers(address(0xbeef), 0, pair2.voucher1().balanceOf(address(0xbeef)));

        // "pre-swap" for L1
        uint256 expectedMarked0 = pair2.voucher1().totalSupply() - pair2.voucher1().balanceOf(address(pair2));
        uint256 expectedMarked1 = pair2.voucher0().totalSupply() - pair2.voucher0().balanceOf(address(pair2));

        _standardSyncToL1(L2_FORK_ID);

        vm.selectFork(L1_FORK_ID);
        assertTrue(_k(dove.reserve0(), dove.reserve1()) >= k, "F for curve");
        k = _k(dove.reserve0(), dove.reserve1());

        _standardSyncToL1(L3_FORK_ID);

        // Reminder that both L2s underwent same exact changes
        // check # of earmarked tokens in both Dove and the fountain
        vm.selectFork(L1_FORK_ID);
        assertTrue(_k(dove.reserve0(), dove.reserve1()) >= k, "F for curve");

        assertEq(dove.marked0(L2_DOMAIN), expectedMarked0);
        assertEq(dove.marked1(L2_DOMAIN), expectedMarked1);
        assertEq(dove.marked0(L3_DOMAIN), expectedMarked0);
        assertEq(dove.marked1(L3_DOMAIN), expectedMarked1);

        // todo : remove magic numbers and find out amounts by parsing logs
        // bridged0 = 166569749000000000000
        // bridged1 = 166566667
        // fees0    = 166566666125844726263
        // fees1    = 166566667

        uint256 pairBalance0 = 166569749000000000000 - 166566666125844726263;
        uint256 pairBalance1 = 166566667 - 166566667;

        // check that reserves were impacted properly
        assertEq(dove.reserve0(), initialR0 + (2 * pairBalance0) - (2 * expectedMarked0));
        assertEq(dove.reserve1(), initialR1 + (2 * pairBalance1) - (2 * expectedMarked1));
    }

    function testSyncsWithVouchers() external {
        vm.selectFork(L1_FORK_ID);
        uint256 initialR0 = dove.reserve0();
        uint256 initialR1 = dove.reserve1();
        uint256 k = _k(initialR0, initialR1);

        _syncToL2(L2_FORK_ID);
        _syncToL2(L3_FORK_ID);
        _doSomeSwaps();
        _doSomeSwapsOnL3();
        uint256 expectedMarked0 = pair2.voucher1().totalSupply();
        uint256 expectedMarked1 = pair2.voucher0().totalSupply();

        _standardSyncToL1(L2_FORK_ID);

        vm.selectFork(L1_FORK_ID);
        assertTrue(_k(dove.reserve0(), dove.reserve1()) >= k, "F for curve");
        k = _k(dove.reserve0(), dove.reserve1());

        _standardSyncToL1(L3_FORK_ID);

        // Reminder that both L2s underwent same exact changes
        // check # of earmarked tokens in both Dove and the fountain
        vm.selectFork(L1_FORK_ID);
        assertTrue(_k(dove.reserve0(), dove.reserve1()) >= k, "F for curve");

        assertEq(dove.marked0(L2_DOMAIN), expectedMarked0);
        assertEq(dove.marked1(L2_DOMAIN), expectedMarked1);
        assertEq(dove.marked0(L3_DOMAIN), expectedMarked0);
        assertEq(dove.marked1(L3_DOMAIN), expectedMarked1);

        // todo : remove magic numbers and find out amounts by parsing logs
        // bridged0 = 49833333333333333333334
        // bridged1 = 0
        // fees0    = 136666666666666666666
        // fees1    = 166566667

        uint256 pairBalance0 = 49833333333333333333334;
        uint256 pairBalance1 = 0;

        // check that reserves were impacted properly
        assertEq(dove.reserve0(), initialR0 + (2 * pairBalance0) - (2 * expectedMarked0));
        assertEq(dove.reserve1(), initialR1 + (2 * pairBalance1) - (2 * expectedMarked1));
    }

    function _doSomeSwapsOnL3() internal {
        vm.selectFork(L3_FORK_ID);
        uint256 amount0In;
        uint256 amount1In;
        uint256 amount0Out;
        uint256 amount1Out;

        amount0In = 50000 * 10 ** 6; // 50k usdc
        amount1Out = pair2.getAmountOut(amount0In, pair2.token0());
        routerL3.swapExactTokensForTokensSimple(
            amount0In, amount1Out, pair2.token0(), pair2.token1(), address(0xbeef), block.timestamp + 1000
        );
        /*
            Napkin math
            Balances after fees

            0xbeef trades 50000000000 usdc for 49833330250459178059597 dai
            Not enough held in Pair, so will have to voucher mint entire amount out in dai

            erc20       pair                        0xbeef  
            DAI         0                           0 
            USDC        49833333334                 0
            vDAI        0                           49833330250459178059597
            vUSDC       0                           0

        */
        amount1In = 50000 * 10 ** 18; // 50k dai
        amount0Out = pair2.getAmountOut(amount1In, pair2.token1());
        routerL3.swapExactTokensForTokensSimple(
            amount1In, amount0Out, pair2.token1(), pair2.token0(), address(0xbeef), block.timestamp + 1000
        );
        /*
            Napkin math
            Balances after fees

            0xbeef trades 50000000000000000000000 dai for 49833336416 usdc
            Not enough held in Pair, so will have to voucher mint 3082 vUSDC

            erc20       pair                        0xbeef  
            DAI         49833333333333333333334     0
            USDC        0                           49833333334     
            vDAI        0                           49833330250459178059597
            vUSDC       0                           3082
        */
    }
}
