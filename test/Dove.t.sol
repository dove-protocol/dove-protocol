// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console2.sol";

import {Dove} from "src/L1/Dove.sol";
import {L1Router} from "src/L1/L1Router.sol";
import {L1Factory} from "src/L1/L1Factory.sol";
import {Pair} from "src/L2/Pair.sol";
import {L2Router} from "src/L2/L2Router.sol";
import {L2Factory} from "src/L2/L2Factory.sol";
import {TypeCasts} from "src/hyperlane/TypeCasts.sol";

import {ILayerZeroEndpoint} from "./utils/ILayerZeroEndpoint.sol";
import {LayerZeroPacket} from "./utils/LZPacket.sol";
import {Helper} from "./utils/Helper.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {InterchainGasPaymasterMock} from "./mocks/InterchainGasPaymasterMock.sol";
import {MailboxMock} from "./mocks/MailboxMock.sol";

contract DoveTest is Test, Helper {
    // L1
    address constant L1SGRouter = 0x8731d54E9D02c286767d56ac03e8037C07e01e98;
    InterchainGasPaymasterMock gasMasterL1;
    MailboxMock mailboxL1;
    ILayerZeroEndpoint lzEndpointL1;

    ERC20Mock L1Token0;
    ERC20Mock L1Token1;

    L1Factory factoryL1;
    L1Router routerL1;
    Dove dove;

    // L2
    address constant L2SGRouter = 0x45A01E4e04F14f7A4a6702c74187c5F6222033cd;
    InterchainGasPaymasterMock gasMasterL2;
    MailboxMock mailboxL2;
    ILayerZeroEndpoint lzEndpointL2;

    L2Factory factoryL2;
    L2Router routerL2;
    Pair pair;
    ERC20Mock L2Token0;
    ERC20Mock L2Token1;

    // Misc

    uint256 L1_FORK_ID;
    uint256 L2_FORK_ID;
    uint16 constant L1_CHAIN_ID = 101;
    uint16 constant L2_CHAIN_ID = 109;
    uint32 constant L1_DOMAIN = 0x657468;
    uint32 constant L2_DOMAIN = 0x706f6c79;

    address pairAddress;

    string RPC_ETH_MAINNET = vm.envString("ETH_MAINNET_RPC_URL");
    string RPC_POLYGON_MAINNET = vm.envString("POLYGON_MAINNET_RPC_URL");

    function setUp() external {
        vm.makePersistent(address(this));
        L1_FORK_ID = vm.createSelectFork(RPC_ETH_MAINNET, 16299272);

        /*
            Set all the L1 stuff.
        */
        gasMasterL1 = new InterchainGasPaymasterMock();
        mailboxL1 = new MailboxMock(L1_DOMAIN);
        lzEndpointL1 = ILayerZeroEndpoint(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);

        // preorder how it would be through factory
        L1Token0 = ERC20Mock(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI
        L1Token1 = ERC20Mock(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC

        // deploy factory
        factoryL1 = new L1Factory(address(gasMasterL1), address(mailboxL1), L1SGRouter);
        // deploy router
        routerL1 = new L1Router(address(factoryL1));
        // deploy dove
        dove = Dove(factoryL1.createPair(address(L1Token0), address(L1Token1)));

        // mint tokens
        Helper.mintDAIL1(address(L1Token0), address(this), 10 ** 36);
        Helper.mintUSDCL1(address(L1Token1), address(this), 10 ** 60);
        // provide liquidity
        L1Token0.approve(address(dove), type(uint256).max);
        L1Token1.approve(address(dove), type(uint256).max);
        L1Token0.approve(address(routerL1), type(uint256).max);
        L1Token1.approve(address(routerL1), type(uint256).max);

        (uint256 toAdd0, uint256 toAdd1,) = routerL1.quoteAddLiquidity(address(L1Token0), address(L1Token1), 10 ** 13, 10 ** 25); // 1M of each
        routerL1.addLiquidity(
            address(L1Token0),
            address(L1Token1),
            10 ** 13,
            10 ** 25,
            toAdd0,
            toAdd1,
            address(this),
            type(uint256).max
        );

        // set SG bridges as trusted
        vm.broadcast(address(factoryL1));
        dove.addStargateTrustedBridge(
            109, 0x9d1B1669c73b033DFe47ae5a0164Ab96df25B944, 0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97
        );

        /*
            Set all the L2 stuff.
        */

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

        pair = Pair(factoryL2.createPair(address(L2Token1), address(L2Token0), address(L1Token0), address(L1Token1), address(dove)));

        pairAddress = address(pair);

        Helper.mintUSDCL2(address(L2Token0), address(this), 10 ** 36);
        Helper.mintDAIL2(address(L2Token1), address(this), 10 ** 60);

        L2Token0.approve(address(pair), type(uint256).max);
        L2Token1.approve(address(pair), type(uint256).max);
        L2Token0.approve(address(routerL2), type(uint256).max);
        L2Token1.approve(address(routerL2), type(uint256).max);

        // ---------------------------------------------
        vm.selectFork(L1_FORK_ID);
        vm.broadcast(address(factoryL1));
        dove.addTrustedRemote(L2_DOMAIN, bytes32(uint256(uint160(address(pair)))));

    }

    function testPersistentStatesSwitchingForks() external {
        // on L2 fork id now and switching to L1
        vm.selectFork(L1_FORK_ID);
        assertEq(dove.reserve0(), 10 ** 13);
        vm.selectFork(L2_FORK_ID);
        assertEq(pair.L1Target(), address(dove));
    }

    function testSyncingToL2() external {
        // AMM should be empty
        assertEq(pair.reserve0(), 0);
        assertEq(pair.reserve1(), 0);
        vm.selectFork(L1_FORK_ID);
        uint256 doveReserve0 = dove.reserve0();
        uint256 doveReserve1 = dove.reserve1();
        this.syncToL2();
        assertEq(pair.reserve0(), doveReserve0);
        assertEq(pair.reserve1(), doveReserve1);
        assertEq(pair.L1Target(), address(dove));
    }

    function testSyncingToL1() external {
        this.syncToL2();

        vm.selectFork(L2_FORK_ID);
        _doSomeSwaps();
        uint256 voucher0Balance = pair.voucher0().totalSupply();
        uint256 voucher1Balance = pair.voucher1().totalSupply();

        this.syncToL1();

        vm.selectFork(L1_FORK_ID);

        // proper earmarked tokens
        // have to swap vouchers assert because the ordering of the tokens on L2
        // is not identical to the one on L1 and here it happens that on L1
        // it's [DAI, USDC] and on L2 it's [USDC, DAI]
        assertEq(dove.marked0(L2_DOMAIN), voucher1Balance);
        assertEq(dove.marked1(L2_DOMAIN), voucher0Balance);
    }

    function syncToL2() external {
        vm.selectFork(L1_FORK_ID);
        vm.recordLogs();
        dove.syncL2{value: 1 ether}(L2_CHAIN_ID, address(pair));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Packet event with payload should be the last one
        (address sender, bytes memory payload) = abi.decode(logs[logs.length - 1].data, (address, bytes));
        // switch fork
        vm.selectFork(L2_FORK_ID);
        vm.broadcast(address(mailboxL2));
        pair.handle(L1_DOMAIN, TypeCasts.addressToBytes32(sender), payload);
    }

    function syncToL1() external {
        /*
            Simulate syncing to L1.
            Using Stargate.
        */
        vm.selectFork(L2_FORK_ID);

        vm.recordLogs();
        // remonder it's not ether but MATIC
        pair.syncToL1{value: 800 ether}(1, 1, 3, 3, 200 ether, 200 ether);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // to find LZ events
        //findEvent(logs, 0xe9bded5f24a4168e4f3bf44e00298c993b22376aad8c58c7dda9718a54cbea82);
        // to find mock mailbox events
        //findEvent(logs, 0x3b31784f245377d844a88ed832a668978c700fd9d25d80e8bf5ef168c6bffa20);

        bytes memory payload1 = abi.decode(logs[10].data, (bytes));
        LayerZeroPacket.Packet memory packet1 = LayerZeroPacket.getCustomPacket(payload1);
        bytes memory payload2 = abi.decode(logs[21].data, (bytes));
        LayerZeroPacket.Packet memory packet2 = LayerZeroPacket.getCustomPacket(payload2);

        (address sender1, bytes memory HLpayload1) = abi.decode(logs[12].data, (address, bytes));
        (address sender2, bytes memory HLpayload2) = abi.decode(logs[23].data, (address, bytes));

        // switch fork
        vm.selectFork(L1_FORK_ID);
        bytes memory path = abi.encodePacked(packet1.srcAddress, packet1.dstAddress);
        vm.store(
            address(lzEndpointL1),
            keccak256(abi.encodePacked(path, keccak256(abi.encodePacked(uint256(packet1.srcChainId), uint256(5))))),
            bytes32(uint256(packet1.nonce))
        );
        // larp as default library
        vm.startBroadcast(0x4D73AdB72bC3DD368966edD0f0b2148401A178E2);
        lzEndpointL1.receivePayload(
            packet1.srcChainId, path, packet1.dstAddress, packet1.nonce + 1, 600000, packet1.payload
        );
        lzEndpointL1.receivePayload(
            packet2.srcChainId, path, packet2.dstAddress, packet2.nonce + 1, 600000, packet2.payload
        );
        vm.stopBroadcast();

        (,address token1 ,uint256 marked1, uint256 balance1) = abi.decode(HLpayload1, (uint256, address, uint256, uint256));
        (,address token2,uint256 marked2, uint256 balance2) = abi.decode(HLpayload2, (uint256, address, uint256, uint256));

        vm.startBroadcast(address(mailboxL1));
        dove.handle(L2_DOMAIN, TypeCasts.addressToBytes32(sender1), HLpayload1);
        dove.handle(L2_DOMAIN, TypeCasts.addressToBytes32(sender2), HLpayload2);
        vm.stopBroadcast();
    }

    function findEvent(Vm.Log[] memory logs, bytes32 topic) internal {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == topic) {
                console2.logUint(i);
            }
        }
    }

    function _doSomeSwaps() internal {
        vm.selectFork(L2_FORK_ID);
        uint256 amount0In;
        uint256 amount1In;
        uint256 amount0Out;
        uint256 amount1Out;

        amount0In = 500000 * 10**6; // 500k usdc
        amount1Out = pair.getAmountOut(amount0In, pair.token0());
        routerL2.swapExactTokensForTokensSimple(
            amount0In, amount1Out, pair.token0(), pair.token1(), address(0xbeef), block.timestamp + 1000
        );

        amount1In = 500000 * 10**18; // 500k dai
        amount0Out = pair.getAmountOut(amount1In, pair.token1());
        routerL2.swapExactTokensForTokensSimple(
            amount1In, amount0Out, pair.token1(), pair.token0(), address(0xbeef), block.timestamp + 1000
        );

    }

    receive() external payable {}
}
