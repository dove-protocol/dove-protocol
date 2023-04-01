// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/console.sol";
import "./DoveBase.sol";

contract DoveMultiSyncTest is DoveBase {
    // L3 = Optimism
    /**
     * Important note :
     *     When we say "L3", it's synonymous with *another* L2.
     */
    address constant L3SGRouter = 0xB0D502E938ed5f4df2E681fE6E419ff29631d62b;
    InterchainGasPaymasterMock gasMasterL3;
    MailboxMock mailboxL3;
    ILayerZeroEndpoint lzEndpointL3;

    L2Factory factoryL3;
    L2Router routerL3;
    Pair pair2;
    ERC20Mock L3Token0;
    ERC20Mock L3Token1;

    // Misc

    uint256 L3_FORK_ID;
    uint16 constant L3_CHAIN_ID = 111;
    uint32 constant L3_DOMAIN = 10;

    address pair2Address;

    string RPC_OPTIMISM_MAINNET = vm.envString("OPTIMISM_MAINNET_RPC_URL");

    function setUp() external {
        _setUp();

        // L1
        vm.broadcast(address(factoryL1));
        dove.addStargateTrustedBridge(
            111, 0x701a95707A0290AC8B90b3719e8EE5b210360883, 0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97
        );

        /*
            Set all the L3 stuff.
        */

        L3_FORK_ID = vm.createSelectFork(RPC_OPTIMISM_MAINNET, 68636494);

        gasMasterL3 = new InterchainGasPaymasterMock();
        mailboxL3 = new MailboxMock(L3_DOMAIN);
        lzEndpointL3 = ILayerZeroEndpoint(0x3c2269811836af69497E5F486A85D7316753cf62);

        L3Token0 = ERC20Mock(0x7F5c764cBc14f9669B88837ca1490cCa17c31607); // USDC
        L3Token1 = ERC20Mock(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1); // DAI

        // deploy factory
        factoryL3 = new L2Factory(address(gasMasterL3), address(mailboxL3), L3SGRouter, L1_CHAIN_ID, L1_DOMAIN);
        // deploy router
        routerL3 = new L2Router(address(factoryL3));
        IL2Factory.SGConfig memory sgConfig =
            IL2Factory.SGConfig({srcPoolId0: 1, dstPoolId0: 1, srcPoolId1: 3, dstPoolId1: 3});
        pair2 = Pair(
            factoryL3.createPair(
                address(L3Token1), address(L3Token0), sgConfig, address(L1Token0), address(L1Token1), address(dove)
            )
        );

        pair2Address = address(pair2);

        vm.label(pair2Address, "PairL3");

        vm.broadcast(0x625E7708f30cA75bfd92586e17077590C60eb4cD);
        L3Token0.transfer(address(this), 10 ** 13);
        vm.broadcast(0xad32aA4Bff8b61B4aE07E3BA437CF81100AF0cD7);
        L3Token1.transfer(address(this), 10 ** 25);

        L3Token0.approve(address(pair), type(uint256).max);
        L3Token1.approve(address(pair), type(uint256).max);
        L3Token0.approve(address(routerL3), type(uint256).max);
        L3Token1.approve(address(routerL3), type(uint256).max);

        forkToDomain[L3_FORK_ID] = L3_DOMAIN;
        forkToChainId[L3_FORK_ID] = L3_CHAIN_ID;
        forkToPair[L3_FORK_ID] = address(pair2);
        forkToMailbox[L3_FORK_ID] = address(mailboxL3);

        // ---------------------------------------------
        vm.selectFork(L1_FORK_ID);
        vm.broadcast(address(factoryL1));
        dove.addTrustedRemote(L3_DOMAIN, bytes32(uint256(uint160(address(pair2)))));
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

        vm.recordLogs();
        _standardSyncToL1(L3_FORK_ID);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        SyncEventAsStruct memory syncEvent = _extractSyncFinalizedEvent(logs);

        // Reminder that both L2s underwent same exact changes
        // check # of earmarked tokens in both Dove and the fountain
        vm.selectFork(L1_FORK_ID);
        assertTrue(_k(dove.reserve0(), dove.reserve1()) >= k, "F for curve");

        (uint128 a, uint128 b) = dove.marked(L2_DOMAIN);
        assertEq(a, expectedMarked0);
        assertEq(b, expectedMarked1);
        (a, b) = dove.marked(L3_DOMAIN);
        assertEq(a, expectedMarked0);
        assertEq(b, expectedMarked1);

        // check that reserves were impacted properly
        assertEq(dove.reserve0(), initialR0 + (2 * syncEvent.pairBalance0) - (2 * expectedMarked0), "reserve0 not impacted properly");
        assertEq(dove.reserve1(), initialR1 + (2 * syncEvent.pairBalance1) - (2 * expectedMarked1), "reserve1 not impacted properly");
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


        vm.recordLogs();
        _standardSyncToL1(L3_FORK_ID);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        SyncEventAsStruct memory syncEvent = _extractSyncFinalizedEvent(logs);

        // Reminder that both L2s underwent same exact changes
        // check # of earmarked tokens in both Dove and the fountain
        vm.selectFork(L1_FORK_ID);
        assertTrue(_k(dove.reserve0(), dove.reserve1()) >= k, "F for curve");

        (uint128 a, uint128 b) = dove.marked(L2_DOMAIN);
        assertEq(a, expectedMarked0);
        assertEq(b, expectedMarked1);
        (a, b) = dove.marked(L3_DOMAIN);
        assertEq(a, expectedMarked0);
        assertEq(b, expectedMarked1);

        // check that reserves were impacted properly
        assertEq(dove.reserve0(), initialR0 + (2 * syncEvent.pairBalance0) - (2 * expectedMarked0), "reserve0 not impacted properly");
        assertEq(dove.reserve1(), initialR1 + (2 * syncEvent.pairBalance1) - (2 * expectedMarked1), "reserve1 not impacted properly");
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
        amount1In = 50000 * 10 ** 18; // 50k dai
        amount0Out = pair2.getAmountOut(amount1In, pair2.token1());
        routerL3.swapExactTokensForTokensSimple(
            amount1In, amount0Out, pair2.token1(), pair2.token0(), address(0xbeef), block.timestamp + 1000
        );
    }
}
