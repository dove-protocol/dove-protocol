// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./DoveBase.sol";
import "./mocks/SGAttacker.sol";

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

    function testSGAttemptAttackHasNoImpactOnSync_WithRightSyncOrder() external {
        vm.selectFork(L1_FORK_ID);
        uint256 k = _k(dove.reserve0(), dove.reserve1());

        // deploy attacker
        vm.selectFork(L2_FORK_ID);
        SGAttacker attacker = new SGAttacker();

        _syncToL2();

        vm.selectFork(L2_FORK_ID);
        _doSomeSwaps();

        // attack before syncing to L1
        bytes32 LZTopic = 0xe9bded5f24a4168e4f3bf44e00298c993b22376aad8c58c7dda9718a54cbea82;
        vm.selectFork(L2_FORK_ID);

        vm.deal(address(attacker), 1000 ether);
        // credit attacker with USDC
        vm.startBroadcast(0xF977814e90dA44bFA03b6295A0616a897441aceC);
        ERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174).transfer(address(attacker), 100 * 10**6);
        vm.stopBroadcast();

        vm.recordLogs();
        attacker.attack(
            0x45A01E4e04F14f7A4a6702c74187c5F6222033cd,
            101,
            1,
            1,
            0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
            100 * 10**6,
            address(dove)
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes memory attackPayload = abi.decode(_findOneLog(logs, LZTopic).data, (bytes));
        _handleSGMessage(attackPayload);

        _standardSyncToL1();

        vm.selectFork(L1_FORK_ID);
        assertTrue(_k(dove.reserve0(), dove.reserve1()) >= k);
    }

    function testSGAttemptAttackHasNoImpactOnSync_WithWorstSyncOrder() external {
        vm.selectFork(L1_FORK_ID);
        uint256 k = _k(dove.reserve0(), dove.reserve1());

        // deploy attacker
        vm.selectFork(L2_FORK_ID);
        SGAttacker attacker = new SGAttacker();

        _syncToL2();

        vm.selectFork(L2_FORK_ID);
        _doSomeSwaps();

        // ######## ATTACK BEFORE SYNCING TO L1 ########
        bytes32 LZTopic = 0xe9bded5f24a4168e4f3bf44e00298c993b22376aad8c58c7dda9718a54cbea82;
        vm.selectFork(L2_FORK_ID);

        vm.deal(address(attacker), 1000 ether);
        // credit attacker with USDC
        vm.startBroadcast(0xF977814e90dA44bFA03b6295A0616a897441aceC);
        ERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174).transfer(address(attacker), 100 * 10**6);
        vm.stopBroadcast();

        vm.recordLogs();
        attacker.attack(
            0x45A01E4e04F14f7A4a6702c74187c5F6222033cd,
            101,
            1,
            1,
            0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174,
            100 * 10**6,
            address(dove)
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes memory attackPayload = abi.decode(_findOneLog(logs, LZTopic).data, (bytes));
        _handleSGMessage(attackPayload);

        // At this point, 99940000 USDC bridged

        vm.selectFork(L2_FORK_ID);
        // credit attacker with DAI
        vm.startBroadcast(0x27F8D03b3a2196956ED754baDc28D73be8830A6e);
        ERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063).transfer(address(attacker), 100 * 10**18);
        vm.stopBroadcast();

        vm.recordLogs();
        attacker.attack(
            0x45A01E4e04F14f7A4a6702c74187c5F6222033cd,
            101,
            3,
            3,
            0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            100 * 10**18,
            address(dove)
        );
        logs = vm.getRecordedLogs();
        attackPayload = abi.decode(_findOneLog(logs, LZTopic).data, (bytes));
        _handleSGMessage(attackPayload);

        // ######## ATTACK FINISHED ########

        uint256[] memory order = new uint[](4);
        order[0] = 2;
        order[1] = 3;
        order[2] = 0;
        order[3] = 1;
        _syncToL1(order, _handleHLMessage, _handleHLMessage, _handleSGMessage, _handleSGMessage);

        vm.selectFork(L1_FORK_ID);
        // shouldn't have changed because the sync still pending
        // magic numbers
        // fees0 = 166566666125844726263
        // fees1 = 166566667
        assertEq(_k(dove.reserve0(), dove.reserve1()), k);
        // finalize sync
        vm.recordLogs();
        dove.finalizeSyncFromL2(L2_DOMAIN, 0);
        logs = vm.getRecordedLogs();
        assertTrue(_k(dove.reserve0(), dove.reserve1()) >= k);
        // fees should have gone up by almost 100 each given the attacker sent them
        bytes32 feesTopic = 0xe47e312e14ed22581dccdf9557c3dd18d0ef990e87fc3f6dcf6bcdde1d13d1e8;
        Vm.Log memory feesLog = _findOneLog(logs, feesTopic);
        (uint256 fees0, uint256 fees1) = abi.decode(feesLog.data, (uint256, uint256));
        // todo : actually retrieved bridged amounts and not use a margin error
        assertApproxEqAbs(fees0, 136666666666666666666 + 10**20, 10**18);
        assertApproxEqAbs(fees1, 166566667 + 10**8, 10**6);


    }

    function _findOneLog(Vm.Log[] memory logs, bytes32 topic) internal returns (Vm.Log memory) {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == topic) {
                return logs[i];
            }
        }
    }
}
