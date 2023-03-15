// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "@t/DoveBase.sol";

contract DoveSolvencySim is DoveBase {

    uint128 originalReserve0;
    uint128 originalReserve1;

    function setUp() external {
        _setUp();

        vm.selectFork(L1_FORK_ID);
        (originalReserve0, originalReserve1) = dove.getReserves();
    }

    function test() external {
        _resetL2();
        _syncToL2(L2_FORK_ID);
        _singleSwap();
        _standardSyncToL1(L2_FORK_ID);

        _resetL2();
        vm.selectFork(L2_FORK_ID);
        _singleSwap();
        _standardSyncToL1(L2_FORK_ID); // <-- should fail !!

    }

    function _resetL2() internal {
        L2_FORK_ID = vm.createSelectFork(RPC_POLYGON_MAINNET, 37469953);

        gasMasterL2 = new InterchainGasPaymasterMock();
        mailboxL2 = new MailboxMock(L2_DOMAIN);
        lzEndpointL2 = ILayerZeroEndpoint(0x3c2269811836af69497E5F486A85D7316753cf62);

        L2Token0 = ERC20Mock(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174); // USDC
        L2Token1 = ERC20Mock(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063); // DAI

        // deploy factory
        factoryL2 = new L2Factory(address(gasMasterL2), address(mailboxL2), L2SGRouter, L1_CHAIN_ID, L1_DOMAIN);
        // deploy router
        routerL2 = new L2Router(address(factoryL2));
        IL2Factory.SGConfig memory sgConfig =
            IL2Factory.SGConfig({srcPoolId0: 1, dstPoolId0: 1, srcPoolId1: 3, dstPoolId1: 3});
        pair = Pair(
            factoryL2.createPair(
                address(L2Token1), address(L2Token0), sgConfig, address(L1Token0), address(L1Token1), address(dove)
            )
        );

        pairAddress = address(pair);

        vm.label(pairAddress, "PairL2");

        Helper.mintUSDCL2(address(L2Token0), address(this), 10 ** 36);
        Helper.mintDAIL2(address(L2Token1), address(this), 10 ** 60);

        L2Token0.approve(address(pair), type(uint256).max);
        L2Token1.approve(address(pair), type(uint256).max);
        L2Token0.approve(address(routerL2), type(uint256).max);
        L2Token1.approve(address(routerL2), type(uint256).max);

        forkToDomain[L2_FORK_ID] = L2_DOMAIN;
        forkToChainId[L2_FORK_ID] = L2_CHAIN_ID;
        forkToPair[L2_FORK_ID] = address(pair);
        forkToMailbox[L2_FORK_ID] = address(mailboxL2);

        // ---------------------------------------------
        vm.selectFork(L1_FORK_ID);
        vm.broadcast(address(factoryL1));
        dove.addTrustedRemote(L2_DOMAIN, bytes32(uint256(uint160(address(pair)))));

        (uint256 oldReserve0, uint256 oldReserve1) = dove.getReserves();
        uint256 loriginalReserve0 = uint256(originalReserve0);
        // temporarily use original reserves for the sync
        bytes32 slot = bytes32(uint256(originalReserve1));
        assembly {
            slot := or(shl(128, slot), loriginalReserve0)
        }
        vm.store(address(dove), bytes32(uint256(13)), slot);

        _syncToL2(L2_FORK_ID);

        // restore reserves
        vm.selectFork(L1_FORK_ID);
        slot = bytes32(uint256(oldReserve1));
        assembly {
            slot := or(shl(128, slot), oldReserve0)
        }
        vm.store(address(dove), bytes32(uint256(13)), slot);


    }

    function _singleSwap() internal {
        vm.selectFork(L2_FORK_ID);
        uint256 amount0In;
        uint256 amount1In;
        uint256 amount0Out;
        uint256 amount1Out;

        amount0In = 6000000 * 10 ** 6; // 1M usdc
        amount1Out = pair.getAmountOut(amount0In, pair.token0());
        routerL2.swapExactTokensForTokensSimple(
            amount0In, amount1Out, pair.token0(), pair.token1(), address(0xbeef), block.timestamp + 1000
        );


        amount1In = 50000 * 10 ** 18; // 50k dai
        amount0Out = pair.getAmountOut(amount1In, pair.token1());
        routerL2.swapExactTokensForTokensSimple(
            amount1In, amount0Out, pair.token1(), pair.token0(), address(0xbeef), block.timestamp + 1000
        );

        uint256 voucher0Delta = uint256(vm.load(address(pair), bytes32(uint256(19))));
        uint256 voucher1Delta = uint256(vm.load(address(pair), bytes32(uint256(19))));
        assembly {
            voucher0Delta := and(voucher0Delta, 0xffffffffffffffffffffffffffffffff)
            voucher1Delta := shr(128, voucher1Delta)
        }
        console.log("voucher0Delta", voucher0Delta);
        console.log("voucher1Delta", voucher1Delta);
    }
}