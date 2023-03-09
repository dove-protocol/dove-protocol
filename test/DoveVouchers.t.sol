// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./DoveBase.sol";

contract DoveVouchersTest is DoveBase {
    function setUp() external {
        _setUp();
    }

    /*
            Napkin math
            Expected balances (after fees) after _doMoreSwaps() :

            erc20       pair                        0xfeeb  
            DAI         45148999999641686690942     0
            USDC        4684333334                  299000000     
            vDAI        0                           0
            vUSDC       0                           0
            ---------------------------------------------------
                        0xcafe  
            DAI         4983333333691646642392
            USDC        0     
            vDAI        0
            vUSDC       0
            ---------------------------------------------------
                        0xbeef  
            DAI         0
            USDC        49833333334     
            vDAI        49833330250459178059597
            vUSDC       3082
        */

    // Burning vouchers on L2 should result in the user getting the underlying token on L1.
    function testVouchersBurn() external {
        _syncToL2(L2_FORK_ID);
        vm.selectFork(L2_FORK_ID);
        _doMoreSwaps();
        _standardSyncToL1(L2_FORK_ID);

        vm.selectFork(L1_FORK_ID);
        uint256 L1R0 = dove.reserve0();
        uint256 L1R1 = dove.reserve1();

        vm.selectFork(L2_FORK_ID);

        uint256 voucher0Supply = pair.voucher0().totalSupply();
        uint256 voucher1Supply = pair.voucher1().totalSupply();

        // dai
        uint256 voucher1BalanceOfBeef = pair.voucher1().balanceOf(address(0xbeef));

        // burn just one voucher for now
        _burnVouchers(L2_FORK_ID, address(0xbeef), 0, voucher1BalanceOfBeef);

        vm.selectFork(L2_FORK_ID);
        // voucher0 supply doesn't change because we didn't burn it
        assertEq(pair.voucher0().totalSupply(), voucher0Supply);
        assertEq(pair.voucher1().balanceOf(address(0xbeef)), 0);

        vm.selectFork(L1_FORK_ID);

        (uint128 realMarked0, uint128 realMarked1) = dove.marked(L2_DOMAIN);
        assertEq(realMarked0, voucher1Supply - voucher1BalanceOfBeef);
        assertEq(realMarked1, voucher0Supply);
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

        (realMarked0, realMarked1) = dove.marked(L2_DOMAIN);
        assertEq(realMarked0, voucher1Supply - voucher1BalanceOfBeef);
        assertEq(realMarked1, voucher0Supply);
        // reserves should not have changed
        assertEq(dove.reserve0(), L1R0);
        assertEq(dove.reserve1(), L1R1);
        // correctly transfered tokens to user
        assertEq(L1Token0.balanceOf(address(0xbeef)), voucher1BalanceOfBeef);
        assertEq(L1Token0.balanceOf(address(0xcafe)), 0);
    }

    function testVouchersMath() external {
        _syncToL2(L2_FORK_ID);
        vm.selectFork(L2_FORK_ID);
        _doMoreSwaps();

        // before syncing, check correct tokens balances on pair
        assertEq(L2Token0.balanceOf(address(pair)), 4684333334);
        assertEq(L2Token1.balanceOf(address(pair)), 45148999999641686690942);
        assertEq(pair.voucher0().balanceOf(address(pair)), 0);
        assertEq(pair.voucher1().balanceOf(address(pair)), 0);

        _standardSyncToL1(L2_FORK_ID);

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

    function testYeetVouchers() external {
        _syncToL2(L2_FORK_ID);
        vm.selectFork(L2_FORK_ID);
        _doMoreSwaps();
        vm.selectFork(L2_FORK_ID);

        vm.startBroadcast(address(0xbeef));
        uint256 token0BalanceOfBeefBefore = L2Token0.balanceOf(address(0xbeef));
        uint256 token1BalanceOfBeefBefore = L2Token1.balanceOf(address(0xbeef));
        uint256 token0BalanceOfPairBefore = L2Token0.balanceOf(address(pair));
        uint256 token1BalanceOfPairBefore = L2Token1.balanceOf(address(pair));

        uint256 voucher0BalanceOfBeefBefore = pair.voucher0().balanceOf(address(0xbeef));
        uint256 voucher1BalanceOfBeefBefore = pair.voucher1().balanceOf(address(0xbeef));
        uint256 voucher0BalanceOfPairBefore = pair.voucher0().balanceOf(address(pair));
        uint256 voucher1BalanceOfPairBefore = pair.voucher1().balanceOf(address(pair));

        uint256 amount0BeefYeeting = pair.voucher0().balanceOf(address(0xbeef));
        uint256 amount1BeefYeeting = L2Token1.balanceOf(address(pair));
        pair.voucher0().approve(address(pair), type(uint256).max);
        pair.voucher1().approve(address(pair), type(uint256).max);
        // because 0xbeef has more vouchers than pair has of dai, we only yeet the pair's balance equivalent
        pair.yeetVouchers(amount0BeefYeeting, amount1BeefYeeting);

        // pair holding of vouchers should have increased by what beef swapped in
        assertEq(pair.voucher0().balanceOf(address(pair)), voucher0BalanceOfPairBefore + amount0BeefYeeting);
        assertEq(pair.voucher1().balanceOf(address(pair)), voucher1BalanceOfPairBefore + amount1BeefYeeting);
        // inverse for beef
        assertEq(pair.voucher0().balanceOf(address(0xbeef)), voucher0BalanceOfBeefBefore - amount0BeefYeeting);
        assertEq(pair.voucher1().balanceOf(address(0xbeef)), voucher1BalanceOfBeefBefore - amount1BeefYeeting);

        // inversely, beef tokens holding increase by the same amount of vouchers he yeeted
        assertEq(L2Token0.balanceOf(address(0xbeef)), token0BalanceOfBeefBefore + amount0BeefYeeting);
        assertEq(L2Token1.balanceOf(address(0xbeef)), token1BalanceOfBeefBefore + amount1BeefYeeting);
        // inverse for pair
        assertEq(L2Token0.balanceOf(address(pair)), token0BalanceOfPairBefore - amount0BeefYeeting);
        assertEq(L2Token1.balanceOf(address(pair)), token1BalanceOfPairBefore - amount1BeefYeeting);

        vm.stopBroadcast();
    }

    function testCannotYeetMoreThanOwned() external {
        _syncToL2(L2_FORK_ID);
        vm.selectFork(L2_FORK_ID);
        _doMoreSwaps();
        vm.selectFork(L2_FORK_ID);

        vm.startBroadcast(address(0xbeef));
        pair.voucher0().approve(address(pair), type(uint256).max);
        pair.voucher1().approve(address(pair), type(uint256).max);
        uint256 amount0BeefYeeting = L2Token0.balanceOf(address(pair));
        vm.expectRevert();
        pair.yeetVouchers(amount0BeefYeeting, 0);
        vm.stopBroadcast();
    }

    // burn message sent from L2 ; not enough earmarked tokens on L1 ; burn is saved
    function testBurnClaim() external {
        _syncToL2(L2_FORK_ID);
        vm.selectFork(L2_FORK_ID);
        _doMoreSwaps();
        vm.selectFork(L2_FORK_ID);

        uint256 voucher1BalanceOfBeef = pair.voucher1().balanceOf(address(0xbeef));

        // 0xbeef wants to burn his DAI vouchers, but he hasn't synced yet, so it should result in a claim
        _burnVouchers(L2_FORK_ID, address(0xbeef), 0, pair.voucher1().balanceOf(address(0xbeef)));
        // sync to L1
        _standardSyncToL1(L2_FORK_ID);
        vm.selectFork(L1_FORK_ID);
        dove.claimBurn(L2_DOMAIN, address(0xbeef));
        // check that the burn was successful
        assertEq(L1Token0.balanceOf(address(0xbeef)), voucher1BalanceOfBeef);
        // trying again the burn would result in no change
        dove.claimBurn(L2_DOMAIN, address(0xbeef));
        assertEq(L1Token0.balanceOf(address(0xbeef)), voucher1BalanceOfBeef);
    }

    function testYeetVouchersAndSync() external {
        _syncToL2(L2_FORK_ID);
        vm.selectFork(L2_FORK_ID);
        _doMoreSwaps();
        vm.selectFork(L2_FORK_ID);

        vm.startBroadcast(address(0xbeef));

        uint256 amount0BeefYeeting = pair.voucher0().balanceOf(address(0xbeef));
        uint256 amount1BeefYeeting = L2Token1.balanceOf(address(pair));
        pair.voucher0().approve(address(pair), type(uint256).max);
        pair.voucher1().approve(address(pair), type(uint256).max);
        // because 0xbeef has more vouchers than pair has of dai, we only yeet the pair's balance equivalent
        pair.yeetVouchers(amount0BeefYeeting, amount1BeefYeeting);

        vm.stopBroadcast();

        vm.selectFork(L1_FORK_ID);
        uint256 k0 = _k(dove.reserve0(), dove.reserve1());

        // sync to L1
        _standardSyncToL1(L2_FORK_ID);

        vm.selectFork(L1_FORK_ID);
        assertTrue(_k(dove.reserve0(), dove.reserve1()) >= k0);
    }
}
