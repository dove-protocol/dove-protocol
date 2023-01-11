// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import {Dove} from "src/L1/Dove.sol";
import {L1Router} from "src/L1/L1Router.sol";
import {L1Factory} from "src/L1/L1Factory.sol";
import {Pair} from "src/L2/Pair.sol";
import {L2Router} from "src/L2/L2Router.sol";
import {IL2Factory, L2Factory} from "src/L2/L2Factory.sol";
import {TypeCasts} from "src/hyperlane/TypeCasts.sol";

import {ILayerZeroEndpoint} from "./utils/ILayerZeroEndpoint.sol";
import {LayerZeroPacket} from "./utils/LZPacket.sol";
import {Helper} from "./utils/Helper.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {InterchainGasPaymasterMock} from "./mocks/InterchainGasPaymasterMock.sol";
import {MailboxMock} from "./mocks/MailboxMock.sol";

/*
    Some of the calculations rely on the state of SG pools at the hardcoded fork blocks.

    A test contract with the following simplifying assumption ; there is only one L2 AMM.

    Given the addresses of token0/1 on L1 and L2, it should be noted that ;

    L1          L2
    token0      token1+voucher1
    token1      token0+voucher0
    marked0     voucher1
    marked1     voucher0*/
contract DoveBase is Test, Helper {
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

    uint256 constant initialLiquidity0 = 10 ** 25;
    uint256 constant initialLiquidity1 = 10 ** 13;

    function _setUp() internal {
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
        Helper.mintDAIL1(address(L1Token0), address(this), 10 ** 60);
        Helper.mintUSDCL1(address(L1Token1), address(this), 10 ** 36);
        // provide liquidity
        L1Token0.approve(address(dove), type(uint256).max);
        L1Token1.approve(address(dove), type(uint256).max);
        L1Token0.approve(address(routerL1), type(uint256).max);
        L1Token1.approve(address(routerL1), type(uint256).max);

        (uint256 toAdd0, uint256 toAdd1,) =
            routerL1.quoteAddLiquidity(address(L1Token0), address(L1Token1), initialLiquidity0, initialLiquidity1); // 10M of each

        routerL1.addLiquidity(
            address(L1Token0),
            address(L1Token1),
            initialLiquidity0,
            initialLiquidity1,
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

        vm.label(address(L2Token0), "USDC");
        vm.label(address(L2Token1), "DAI");

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

    function _burnVouchers(address user, uint256 amount0, uint256 amount1) internal {
        vm.selectFork(L2_FORK_ID);
        vm.recordLogs();
        vm.broadcast(user);
        pair.burnVouchers(amount0, amount1);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        // should be second long
        (address sender, bytes memory HLpayload) = abi.decode(logs[1].data, (address, bytes));
        vm.selectFork(L1_FORK_ID);
        vm.broadcast(address(mailboxL1));
        dove.handle(L2_DOMAIN, TypeCasts.addressToBytes32(sender), HLpayload);
    }

    function _syncToL2() internal {
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

    function _standardSyncToL1() internal {
        uint256[] memory order = new uint[](4);
        order[0] = 0;
        order[1] = 1;
        order[2] = 2;
        order[3] = 3;

        _syncToL1(order, _handleSGMessage, _handleSGMessage, _handleHLMessage, _handleHLMessage);
    }

    function _syncToL1(
        uint256[] memory order,
        function(bytes memory) internal one,
        function(bytes memory) internal two,
        function(bytes memory) internal three,
        function(bytes memory) internal four
    ) internal {
        /*
            Simulate syncing to L1.
            Using Stargate.
        */
        vm.selectFork(L2_FORK_ID);

        vm.recordLogs();
        // reminder it's not ether but MATIC
        pair.syncToL1{value: 800 ether}(200 ether, 200 ether);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // to find LZ events
        //_findEvent(logs, 0xe9bded5f24a4168e4f3bf44e00298c993b22376aad8c58c7dda9718a54cbea82);
        // to find mock mailbox events
        //_findEvent(logs, 0x3b31784f245377d844a88ed832a668978c700fd9d25d80e8bf5ef168c6bffa20);

        // first two payloads are LZ
        // last two are HL
        bytes[] memory payloads = new bytes[](4);
        payloads[0] = abi.decode(logs[10].data, (bytes));
        payloads[1] = abi.decode(logs[21].data, (bytes));
        payloads[2] = logs[12].data;
        payloads[3] = logs[23].data;

        one(payloads[order[0]]);
        two(payloads[order[1]]);
        three(payloads[order[2]]);
        four(payloads[order[3]]);

        // (,address token0,uint256 marked0, uint256 pairBalance0) = abi.decode(HLpayload1, (uint,address,uint,uint));
        // (,address token1,uint256 marked1, uint256 pairBalance1) = abi.decode(HLpayload2, (uint,address,uint,uint));
        // console.log("Hyperlane payload0...");
        // console.log("token", token0);
        // console.log("marked", marked0);
        // console.log("pairBalance", pairBalance0);
        // console.log("Hyperlane payload1...");
        // console.log("token", token1);
        // console.log("marked", marked1);
        // console.log("pairBalance", pairBalance1);
    }

    function _handleSGMessage(bytes memory payload) internal {
        LayerZeroPacket.Packet memory packet = LayerZeroPacket.getCustomPacket(payload);
        // switch fork
        vm.selectFork(L1_FORK_ID);
        bytes memory path = abi.encodePacked(packet.srcAddress, packet.dstAddress);
        vm.store(
            address(lzEndpointL1),
            keccak256(abi.encodePacked(path, keccak256(abi.encodePacked(uint256(packet.srcChainId), uint256(5))))),
            bytes32(uint256(packet.nonce))
        );
        // larp as default library
        vm.broadcast(0x4D73AdB72bC3DD368966edD0f0b2148401A178E2);
        lzEndpointL1.receivePayload(
            packet.srcChainId, path, packet.dstAddress, packet.nonce + 1, 600000, packet.payload
        );
    }

    function _handleHLMessage(bytes memory payload) internal {
        vm.selectFork(L1_FORK_ID);
        (address sender, bytes memory HLpayload) = abi.decode(payload, (address, bytes));
        vm.broadcast(address(mailboxL1));
        dove.handle(L2_DOMAIN, TypeCasts.addressToBytes32(sender), HLpayload);
    }

    function _findEvent(Vm.Log[] memory logs, bytes32 topic) internal {
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

        amount0In = 50000 * 10 ** 6; // 50k usdc
        amount1Out = pair.getAmountOut(amount0In, pair.token0());
        routerL2.swapExactTokensForTokensSimple(
            amount0In, amount1Out, pair.token0(), pair.token1(), address(0xbeef), block.timestamp + 1000
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
        amount0Out = pair.getAmountOut(amount1In, pair.token1());
        routerL2.swapExactTokensForTokensSimple(
            amount1In, amount0Out, pair.token1(), pair.token0(), address(0xbeef), block.timestamp + 1000
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

    function _doMoreSwaps() internal {
        _doSomeSwaps();

        uint256 amount0In;
        uint256 amount1In;
        uint256 amount0Out;
        uint256 amount1Out;

        amount0In = 5000 * 10 ** 6; // 5k usdc
        amount1Out = pair.getAmountOut(amount0In, pair.token0());
        routerL2.swapExactTokensForTokensSimple(
            amount0In, amount1Out, pair.token0(), pair.token1(), address(0xcafe), block.timestamp + 1000
        );
        /*
            Napkin math
            Balances after fees

            0xcafe trades 5000000000 usdc for 4983333333691646642392 dai

            erc20       pair                        0xcafe  
            DAI         44849999999641686690942     4983333333691646642392
            USDC        4983333334                  0     
            vDAI        0                           0
            vUSDC       0                           0
        */
        amount1In = 300 * 10 ** 18; // 300 dai
        amount0Out = pair.getAmountOut(amount1In, pair.token1());
        routerL2.swapExactTokensForTokensSimple(
            amount1In, amount0Out, pair.token1(), pair.token0(), address(0xfeeb), block.timestamp + 1000
        );
        /*
            Napkin math
            Balances after fees

            0xfeeb trades 300000000000000000000 dai for 299000000 usdc

            erc20       pair                        0xfeeb  
            DAI         45148999999641686690942     0
            USDC        4684333334                  299000000     
            vDAI        0                           0
            vUSDC       0                           0
        */
    }

    function _k(uint256 x, uint256 y) internal view returns (uint256) {
        uint256 _x = (x * 1e18) / uint64(10 ** 18);
        uint256 _y = (y * 1e18) / uint64(10 ** 6);
        uint256 _a = (_x * _y) / 1e18;
        uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
        return (_a * _b) / 1e18; // x3y+y3x >= k
    }

    receive() external payable {}
}
