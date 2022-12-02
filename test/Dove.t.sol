// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console2.sol";

import {Dove} from "src/L1/Dove.sol";
import {AMM} from "src/L2/AMM.sol";
import {TypeCasts} from "src/hyperlane/TypeCasts.sol";

import {ILayerZeroEndpoint} from "./utils/ILayerZeroEndpoint.sol";
import {LayerZeroPacket} from "./utils/LZPacket.sol";
import {Helper} from "./utils/Helper.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {InterchainGasPaymasterMock} from "./mocks/InterchainGasPaymasterMock.sol";
import {MailboxMock} from "./mocks/MailboxMock.sol";

contract DoveTest is Test, Helper {
    // L1
    InterchainGasPaymasterMock gasMasterL1;
    MailboxMock mailboxL1;
    ILayerZeroEndpoint lzEndpointL1;

    ERC20Mock token0L1;
    ERC20Mock token1L1;

    Dove dove;

    // L2
    InterchainGasPaymasterMock gasMasterL2;
    MailboxMock mailboxL2;
    ILayerZeroEndpoint lzEndpointL2;

    AMM amm;
    ERC20Mock token0L2;
    ERC20Mock token1L2;

    // Misc

    uint256 L1_FORK_ID;
    uint256 L2_FORK_ID;
    uint16 constant L1_CHAIN_ID = 101;
    uint16 constant L2_CHAIN_ID = 109;
    uint32 constant L1_DOMAIN = 0x657468;
    uint32 constant L2_DOMAIN = 0x706f6c79;

    address ammAddress;

    string RPC_ETH_MAINNET = vm.envString("ETH_MAINNET_RPC_URL");
    string RPC_POLYGON_MAINNET = vm.envString("POLYGON_MAINNET_RPC_URL");

    function setUp() external {
        vm.makePersistent(address(this));
        L1_FORK_ID = vm.createSelectFork(RPC_ETH_MAINNET);

        /*
            Set all the L1 stuff.
        */
        gasMasterL1 = new InterchainGasPaymasterMock();
        mailboxL1 = new MailboxMock(L1_DOMAIN);
        lzEndpointL1 = ILayerZeroEndpoint(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);

        token0L1 = ERC20Mock(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC
        token1L1 = ERC20Mock(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI

        dove = new Dove(
            address(token0L1),
            address(token1L1),
            address(gasMasterL1),
            address(mailboxL1),
            0x8731d54E9D02c286767d56ac03e8037C07e01e98
        );

        // mint tokens
        Helper.mintUSDCL1(address(token0L1), address(this), 10 ** 20);
        Helper.mintDAIL1(address(token1L1), address(this), 10 ** 20);
        // provide liquidity
        token0L1.approve(address(dove), type(uint256).max);
        token1L1.approve(address(dove), type(uint256).max);
        dove.provide(10 ** 13, 10 ** 13);

        // set SG bridges as trusted
        dove.addStargateTrustedBridge(
            109, 0x9d1B1669c73b033DFe47ae5a0164Ab96df25B944, 0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97
        );

        /*
            Set all the L1 stuff.
        */

        L2_FORK_ID = vm.createSelectFork(RPC_POLYGON_MAINNET);

        gasMasterL2 = new InterchainGasPaymasterMock();
        mailboxL2 = new MailboxMock(L2_DOMAIN);
        lzEndpointL2 = ILayerZeroEndpoint(0x3c2269811836af69497E5F486A85D7316753cf62);

        token0L2 = ERC20Mock(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174); // USDC
        token1L2 = ERC20Mock(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063); // DAI

        amm = new AMM(
            address(token0L2),
            address(token0L1),
            address(token1L2),
            address(token1L1),
            address(gasMasterL2),
            address(mailboxL2),
            0x45A01E4e04F14f7A4a6702c74187c5F6222033cd,
            address(dove),
            L1_CHAIN_ID,
            L1_DOMAIN
        );
        ammAddress = address(amm);

        Helper.mintUSDCL2(address(token0L2), address(this), 10 ** 20);
        Helper.mintDAIL2(address(token1L2), address(this), 10 ** 20);
        token0L2.approve(address(amm), type(uint256).max);
        token1L2.approve(address(amm), type(uint256).max);
    }

    function testPersistentStatesSwitchingForks() external {
        // on L2 fork id now and switching to L1
        vm.selectFork(L1_FORK_ID);
        assertEq(dove.reserve0(), 10 ** 13);
        vm.selectFork(L2_FORK_ID);
        assertEq(amm.L1Target(), address(dove));
    }

    function testSyncingToL2() external {
        // AMM should be empty
        assertEq(amm.reserve0(), 0);
        assertEq(amm.reserve1(), 0);
        vm.selectFork(L1_FORK_ID);
        uint256 doveReserve0 = dove.reserve0();
        uint256 doveReserve1 = dove.reserve1();
        this.syncToL2();
        assertEq(amm.reserve0(), doveReserve0);
        assertEq(amm.reserve1(), doveReserve1);
        assertEq(amm.L1Target(), address(dove));
    }

    function testSyncingToL1() external {
        this.syncToL2();

        vm.selectFork(L2_FORK_ID);
        uint256 out1 = amm.swap(10 ** 10, 0);
        uint256 out2 = amm.swap(0, 10 ** 10);
        uint256 voucher0Balance = amm.voucher0().balanceOf(address(this));
        uint256 voucher1Balance = amm.voucher1().balanceOf(address(this));

        this.syncToL1();

        vm.selectFork(L1_FORK_ID);

        // proper earmarked tokens
        assertEq(dove.marked0(L2_DOMAIN), voucher0Balance);
        assertEq(dove.marked1(L2_DOMAIN), voucher1Balance);
    }

    function syncToL2() external {
        vm.selectFork(L1_FORK_ID);
        vm.recordLogs();
        dove.syncL2{value: 1 ether}(L2_CHAIN_ID, address(amm));
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Packet event with payload should be the last one
        (address sender, bytes memory payload) = abi.decode(logs[logs.length - 1].data, (address, bytes));
        // switch fork
        vm.selectFork(L2_FORK_ID);
        vm.broadcast(address(mailboxL2));
        amm.handle(L1_DOMAIN, TypeCasts.addressToBytes32(sender), payload);
    }

    function syncToL1() external {
        /*
            Simulate syncing to L1.
            Using Stargate.
        */
        vm.selectFork(L2_FORK_ID);

        vm.recordLogs();
        amm.syncToL1{value: 400 ether}(1, 1, 3, 3);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bytes memory payload1 = abi.decode(logs[8].data, (bytes));
        LayerZeroPacket.Packet memory packet1 = LayerZeroPacket.getCustomPacket(payload1);
        bytes memory payload2 = abi.decode(logs[18].data, (bytes));
        LayerZeroPacket.Packet memory packet2 = LayerZeroPacket.getCustomPacket(payload2);

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
    }

    function findEvent(Vm.Log[] memory logs, bytes32 topic) internal {
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == topic) {
                console2.logUint(i);
            }
        }
    }

    receive() external payable {}
}
