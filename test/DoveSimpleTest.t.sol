// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./DoveBase.sol";

contract DoveSimpleTest is DoveBase {
    function setUp() external {
        _setUp();
    }

    /*
        Dove should be able to sync the Pair with itself.
        It does so by communicating with the Pair the reserves of Dove.

        Doing so should not nuke existing state on L2, such as vouchers deltas.
    */
    function testSyncingToL2() external {
        // AMM should be empty
        vm.selectFork(L2_FORK_ID);
        assertEq(pair.reserve0(), 0);
        assertEq(pair.reserve1(), 0);

        vm.selectFork(L1_FORK_ID);

        uint256 doveReserve0 = dove.reserve0();
        uint256 doveReserve1 = dove.reserve1();

        _syncToL2();

        vm.selectFork(L2_FORK_ID);
        // have compare L2R0 to L1R1 because the ordering of the tokens on L2
        assertEq(pair.reserve0(), doveReserve1);
        assertEq(pair.reserve1(), doveReserve0);
    }

    /*
        The Pair syncing to the L1 means it essentially does the following :
        - "impacts" the reserves (assets balances) as it would have been with swaps on L1
        - guarantees that L2 traders have access to the underlying tokens of their vouchers
    */
    function testSyncingToL1() external {
        uint256 k0 = _k(initialLiquidity0, initialLiquidity1);
        _syncToL2();

        vm.selectFork(L2_FORK_ID);
        _doSomeSwaps();
        vm.selectFork(L2_FORK_ID);
        uint256 voucher0Balance = pair.voucher0().totalSupply();
        uint256 voucher1Balance = pair.voucher1().totalSupply();
        uint256 L2R0 = pair.reserve0(); // USDC virtual reserve
        uint256 L2R1 = pair.reserve1(); // DAI virtual reserve

        _standardSyncToL1();

        vm.selectFork(L1_FORK_ID);

        // check proper earmarked tokens
        // have to swap vouchers assert because the ordering of the tokens on L2
        // is not identical to the one on L1 and here it happens that on L1
        // it's [DAI, USDC] and on L2 it's [USDC, DAI]
        assertEq(dove.marked0(L2_DOMAIN), voucher1Balance);
        assertEq(dove.marked1(L2_DOMAIN), voucher0Balance);
        assertEq(L1Token0.balanceOf(address(dove.fountain())), voucher1Balance);
        assertEq(L1Token1.balanceOf(address(dove.fountain())), voucher0Balance);
        // // check reserves impacted properly
        // /*
        //     Napkin math
        //     reserve = reserve + bridged - earmarked

        //     reserve1[USDC]  = 10**(7+6)  + 166566667 - 3082
        //                     = 10000166563585
        //     reserve0[DAI]   = 10**(7+18) + 49970000000000000000000 - 49833330250459178059597
        //                     = 10000136669749540821940403
        // */
        assertEq(dove.reserve0(), L2R1);
        assertEq(dove.reserve1(), L2R0);
        assertTrue(_k(dove.reserve0(), dove.reserve1()) >= k0);
    }

    /*
        Burning vouchers on L2 should result in the user getting the underlying token on L1.
    */
    function testVouchersBurnWithPartialFulfillment() external {
        _syncToL2();
        vm.selectFork(L2_FORK_ID);
        _doMoreSwaps();
        _standardSyncToL1();

        vm.selectFork(L1_FORK_ID);
        uint256 L1R0 = dove.reserve0();
        uint256 L1R1 = dove.reserve1();

        vm.selectFork(L2_FORK_ID);

        uint256 voucher0Supply = pair.voucher0().totalSupply();
        uint256 voucher1Supply = pair.voucher1().totalSupply();

        uint256 voucher0BalanceOfBeef = pair.voucher0().balanceOf(address(0xbeef));
        // dai
        uint256 voucher1BalanceOfBeef = pair.voucher1().balanceOf(address(0xbeef));
        uint256 balance1OfBeef = L2Token1.balanceOf(address(0xbeef));

        (, uint256 toSend1,, uint256 excess1) = pair.getExcessAfterBurn(0, voucher1BalanceOfBeef);

        // burn just one voucher for now
        _burnVouchers(address(0xbeef), 0, voucher1BalanceOfBeef);

        vm.selectFork(L2_FORK_ID);
        // check vouchers has been burnt
        assertEq(pair.voucher0().totalSupply(), voucher0Supply);
        assertEq(pair.voucher1().balanceOf(address(0xbeef)), 0);

        // check amount of tokens sent to user
        assertEq(L2Token1.balanceOf(address(0xbeef)), balance1OfBeef + toSend1);

        vm.selectFork(L1_FORK_ID);

        assertEq(dove.marked1(L2_DOMAIN), voucher0Supply);
        assertEq(dove.marked0(L2_DOMAIN), voucher1Supply - excess1);
        // reserves should not have changed
        assertEq(dove.reserve0(), L1R0);
        assertEq(dove.reserve1(), L1R1);
        // correctly transfered tokens to user on L1
        assertEq(L1Token0.balanceOf(address(0xbeef)), voucher1BalanceOfBeef - toSend1);

        vm.selectFork(L2_FORK_ID);
        // nothing should have happened
        assertEq(pair.voucher1().totalSupply(), voucher1Supply - voucher1BalanceOfBeef);
        assertEq(pair.voucher0().balanceOf(address(0xbeef)), voucher0BalanceOfBeef);
        assertEq(pair.voucher1().balanceOf(address(0xcafe)), 0);
    }

    function testVouchersBurnWithFullFullfillment() external {
        _syncToL2();
        vm.selectFork(L2_FORK_ID);
        _doMoreSwaps();
        _standardSyncToL1();

        vm.selectFork(L1_FORK_ID);
        uint256 L1R0 = dove.reserve0();
        uint256 L1R1 = dove.reserve1();

        vm.selectFork(L2_FORK_ID);

        uint256 voucher0Supply = pair.voucher0().totalSupply();
        uint256 voucher1Supply = pair.voucher1().totalSupply();

        // dai
        uint256 voucher1BalanceOfBeef = pair.voucher1().balanceOf(address(0xbeef));

        // burn just one voucher for now (10 ** 3 is random amount lower than L2 balance)
        vm.broadcast(address(0xbeef));
        pair.burnVouchers(0, 10 ** 3);

        // check vouchers has been burnt
        assertEq(pair.voucher0().totalSupply(), voucher0Supply);
        assertEq(pair.voucher1().balanceOf(address(0xbeef)), voucher1BalanceOfBeef - 10 ** 3);

        assertEq(pair.voucher1().totalSupply(), voucher1Supply - 10 ** 3);
        assertEq(pair.voucher0().balanceOf(address(0xbeef)), 3082);
        assertEq(pair.voucher1().balanceOf(address(0xcafe)), 0);

        // check user received tokens on L2
        assertEq(L2Token1.balanceOf(address(0xbeef)), 10 ** 3);
    }

    function testVouchersMath() external {
        _syncToL2();
        vm.selectFork(L2_FORK_ID);
        _doMoreSwaps();

        // before syncing, check correct tokens balances on pair
        assertEq(L2Token0.balanceOf(address(pair)), 4684333334);
        assertEq(L2Token1.balanceOf(address(pair)), 45148999999641686690942);
        assertEq(pair.voucher0().balanceOf(address(pair)), 0);
        assertEq(pair.voucher1().balanceOf(address(pair)), 0);

        _standardSyncToL1();

        vm.selectFork(L1_FORK_ID);
        uint256 L1R0 = dove.reserve0();
        uint256 L1R1 = dove.reserve1();

        vm.selectFork(L2_FORK_ID);

        // magic numbers based on napkin math
        assertEq(L2Token0.balanceOf(address(0xbeef)), 49833333334);
        assertEq(L2Token1.balanceOf(address(0xbeef)), 0);
        assertEq(pair.voucher0().balanceOf(address(0xbeef)), 3082);
        assertEq(pair.voucher1().balanceOf(address(0xbeef)), 49833330250459178059597);

        assertEq(L2Token0.balanceOf(address(0xcafe)), 0);
        assertEq(L2Token1.balanceOf(address(0xcafe)), 4983333333691646642392);
        assertEq(pair.voucher0().balanceOf(address(0xcafe)), 0);
        assertEq(pair.voucher1().balanceOf(address(0xcafe)), 0);

        assertEq(L2Token0.balanceOf(address(0xfeeb)), 299000000);
        assertEq(L2Token1.balanceOf(address(0xfeeb)), 0);
        assertEq(pair.voucher0().balanceOf(address(0xfeeb)), 0);
        assertEq(pair.voucher1().balanceOf(address(0xfeeb)), 0);
    }

    function testSyncingToL1_withSGSwapsProcessedLast() external {
        _syncToL2();

        vm.selectFork(L2_FORK_ID);
        _doSomeSwaps();

        uint256 voucher0Balance = pair.voucher0().totalSupply();
        uint256 voucher1Balance = pair.voucher1().totalSupply();
        uint256 L2R0 = pair.reserve0(); // USDC virtual reserve
        uint256 L2R1 = pair.reserve1(); // DAI virtual reserve

        uint256[] memory order = new uint[](4);
        order[0] = 2;
        order[1] = 3;
        order[2] = 0;
        order[3] = 1;
        _syncToL1(order, _handleHLMessage, _handleHLMessage, _handleSGMessage, _handleSGMessage);

        vm.selectFork(L1_FORK_ID);
        // given messages weren't in expected order, sync should still be pending
        assertEq(dove.marked0(L2_DOMAIN), 0);
        assertEq(dove.marked1(L2_DOMAIN), 0);

        dove.finalizeSyncFromL2(L2_DOMAIN, 0);

        assertEq(dove.marked0(L2_DOMAIN), voucher1Balance);
        assertEq(dove.marked1(L2_DOMAIN), voucher0Balance);
        assertEq(L1Token0.balanceOf(address(dove.fountain())), voucher1Balance);
        assertEq(L1Token1.balanceOf(address(dove.fountain())), voucher0Balance);
        assertEq(dove.reserve0(), L2R1);
        assertEq(dove.reserve1(), L2R0);
    }

    function testCannotFinalizeTwice() external {
        _syncToL2();

        vm.selectFork(L2_FORK_ID);
        _doSomeSwaps();

        uint256 voucher0Balance = pair.voucher0().totalSupply();
        uint256 voucher1Balance = pair.voucher1().totalSupply();

        uint256[] memory order = new uint[](4);
        order[0] = 2;
        order[1] = 3;
        order[2] = 0;
        order[3] = 1;
        _syncToL1(order, _handleHLMessage, _handleHLMessage, _handleSGMessage, _handleSGMessage);

        vm.selectFork(L1_FORK_ID);
        dove.finalizeSyncFromL2(L2_DOMAIN, 0);
        vm.expectRevert();
        dove.finalizeSyncFromL2(L2_DOMAIN, 0);
    }
}
