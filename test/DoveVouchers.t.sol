// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./DoveBase.sol";

contract DoveFeesTest is DoveBase {
    function setUp() external {
        _setUp();
    }

    // Burning vouchers on L2 should result in the user getting the underlying token on L1.
    function testVouchersBurn() external {
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

        // burn just one voucher for now
        _burnVouchers(address(0xbeef), 0, voucher1BalanceOfBeef);

        vm.selectFork(L2_FORK_ID);
        // check vouchers has been burnt
        assertEq(pair.voucher0().totalSupply(), voucher0Supply);
        assertEq(pair.voucher1().balanceOf(address(0xbeef)), 0);

        vm.selectFork(L1_FORK_ID);

        assertEq(dove.marked1(L2_DOMAIN), voucher0Supply);
        assertEq(dove.marked0(L2_DOMAIN), voucher1Supply - voucher1BalanceOfBeef);
        // reserves should not have changed
        assertEq(dove.reserve0(), L1R0);
        assertEq(dove.reserve1(), L1R1);
        // correctly transfered tokens to user
        assertEq(L1Token0.balanceOf(address(0xbeef)), voucher1BalanceOfBeef);

        vm.selectFork(L2_FORK_ID);
        // nothing should have happened
        assertEq(pair.voucher1().totalSupply(), voucher1Supply - voucher1BalanceOfBeef);
        assertEq(pair.voucher0().balanceOf(address(0xbeef)), 3082);
        assertEq(pair.voucher1().balanceOf(address(0xcafe)), 0);

        vm.selectFork(L1_FORK_ID);

        assertEq(dove.marked1(L2_DOMAIN), voucher0Supply);
        assertEq(dove.marked0(L2_DOMAIN), voucher1Supply - voucher1BalanceOfBeef);
        // reserves should not have changed
        assertEq(dove.reserve0(), L1R0);
        assertEq(dove.reserve1(), L1R1);
        // correctly transfered tokens to user
        assertEq(L1Token0.balanceOf(address(0xbeef)), voucher1BalanceOfBeef);
        assertEq(L1Token0.balanceOf(address(0xcafe)), 0);
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
}