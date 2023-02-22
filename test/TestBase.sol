pragma solidity ^0.8.15;

import { TestUtils } from "./utils/TestUtils.sol";
import { Minter } from "./utils/Minter.sol";

import { Dove } from "../src/L1/Dove.sol";
import { IDove } from "../src/L1/interfaces/IDove.sol";
import { Fountain } from "../src/L1/Fountain.sol";
import { L1Factory } from "../src/L1/L1Factory.sol";
import { L1Router } from "../src/L1/L1Router.sol";
import { SGHyperlaneConverter } from "../src/L1/SGHyperlaneConverter.sol";

import { Pair } from "../src/L2/Pair.sol";
import { FeesAccumulator } from "../src/L2/FeesAccumulator.sol";
import { L2Factory } from "../src/L2/L2Factory.sol";
import { IL2Factory } from "../src/L2/interfaces/IL2Factory.sol";
import { L2Router } from "../src/L2/L2Router.sol";
import { Voucher } from "../src/L2/Voucher.sol";

import { ERC20Mock } from "./mocks/ERC20Mock.sol";
import { InterchainGasPaymasterMock } from "./mocks/InterchainGasPaymasterMock.sol";
import { MailboxMock } from "./mocks/MailboxMock.sol";
import { TypeCasts } from "src/hyperlane/TypeCasts.sol";

import { ILayerZeroEndpoint } from "./utils/ILayerZeroEndpoint.sol";
import { LayerZeroPacket } from "./utils/LZPacket.sol";

import { ProtocolActions } from "./utils/ProtocolActions.sol";

contract TestBase is ProtocolActions, Minter {
    /// constants
    // time
    uint256 internal constant ONE_DAY   = 1 days;
    uint256 internal constant ONE_MONTH = ONE_YEAR / 12;
    uint256 internal constant ONE_YEAR  = 365 days;
    uint256 internal start; // start ts set in constructor
    // L1
    address constant L1SGRouter = 0x8731d54E9D02c286767d56ac03e8037C07e01e98;
    InterchainGasPaymasterMock internal gasMasterL1;
    MailboxMock                internal mailboxL1;
    ILayerZeroEndpoint         internal lzEndpointL1;
    ERC20Mock L1Token0;
    ERC20Mock L1Token1;
    // L2
    address constant L2SGRouter = 0x45A01E4e04F14f7A4a6702c74187c5F6222033cd;
    InterchainGasPaymasterMock internal gasMasterL2;
    MailboxMock                internal mailboxL2;
    ILayerZeroEndpoint         internal lzEndpointL2;
    ERC20Mock L2Token0;
    ERC20Mock L2Token1;

    /// L1 factory deployer
    address internal pauser;

    /// Helper Mappings
    mapping(uint256 => uint32)  forkToDomain;
    mapping(uint256 => uint16)  forkToChainId;
    mapping(uint256 => address) forkToPair;
    mapping(uint256 => address) forkToMailbox;

    /// L1 (Ethereum)
    L1Factory internal factoryL1;
    L1Router  internal routerL1;
    Dove      internal dove01;
    Fountain  internal fountain;

    /// L2 (Polygon)
    L2Factory       internal factoryL2;
    L2Router        internal routerL2;
    Pair            internal pair01Poly;
    FeesAccumulator internal feesAccumulator;
    Voucher         internal voucher;

    /// Fork/Chain IDs
    uint256 L1_FORK_ID;
    uint256 L2_FORK_ID;
    uint16 constant L1_CHAIN_ID = 101;
    uint16 constant L2_CHAIN_ID = 109;
    uint32 constant L1_DOMAIN = 1;
    uint32 constant L2_DOMAIN = 137;

    string RPC_ETH_MAINNET = vm.envString("ETH_MAINNET_RPC_URL");
    string RPC_POLYGON_MAINNET = vm.envString("POLYGON_MAINNET_RPC_URL");

    function setUp() public virtual {
        _createForks();
        vm.selectFork(L1_FORK_ID);

        _setPairTokens01();
        _createFactories();
        // create Dove01 with DAI & USDC
        _createDove01(
            address(this), // owner of initial LP
            address(L1Token0), // DAI
            address(L1Token1), // USDC
            10 ** 60, // token 0 initial amount, 10M
            10 ** 36  // token 1 initial amount, 10M
        );
        vm.label(address(dove01), "DOVE: DAI|USDC");

        // add sg bridges to dove
        _addBridgePoly(address(dove01));

        // compute SGConfig for pairs containing DAI & USDC
        IL2Factory.SGConfig memory sgConfig01 =
            IL2Factory.SGConfig({srcPoolId0: 1, dstPoolId0: 1, srcPoolId1: 3, dstPoolId1: 3});

        // create pair for DAI/USDC on polygon/L2_FORK_ID
        pair01Poly = 
            _createPair01(
                L2_FORK_ID,
                L2_DOMAIN,
                L2_CHAIN_ID,
                address(dove01),
                address(mailboxL2),
                sgConfig01
            );
        vm.label(address(pair01Poly), "PAIR-01-POLY");

        // add pairs as trusted remote
        _addRemotePoly(address(dove01), address(pair01Poly));

        start = block.timestamp;
    }

    /// Initialize
    function _createForks() internal {
        L1_FORK_ID = vm.createFork(RPC_ETH_MAINNET, 16299272);
        L2_FORK_ID = vm.createFork(RPC_POLYGON_MAINNET, 16299272);
    }

    function _setPairTokens01() internal {
        L1Token0 = ERC20Mock(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI
        L1Token1 = ERC20Mock(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC

        L2Token0 = ERC20Mock(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174); // USDC
        L2Token1 = ERC20Mock(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063); // DAI
    }

    function _createFactories() internal {
        //break down factory deployment by each forkID
        vm.makePersistent(address(this));
        vm.selectFork(L1_FORK_ID);
        
        gasMasterL1 = new InterchainGasPaymasterMock();
        mailboxL1 = new MailboxMock(L1_DOMAIN);
        lzEndpointL1 = ILayerZeroEndpoint(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);

        factoryL1 = new L1Factory(address(gasMasterL1), address(mailboxL1), L1SGRouter);
        routerL1 = new L1Router(address(factoryL1));
        pauser = address(this);

        vm.selectFork(L2_FORK_ID);

        gasMasterL2 = new InterchainGasPaymasterMock();
        mailboxL2 = new MailboxMock(L2_DOMAIN);
        lzEndpointL2 = ILayerZeroEndpoint(0x3c2269811836af69497E5F486A85D7316753cf62);

        factoryL2 = new L2Factory(address(gasMasterL2), address(mailboxL2), L2SGRouter, L1_CHAIN_ID, L1_DOMAIN);
        routerL2 = new L2Router(address(factoryL2));
    }

    function _createDove01(
        address _ownerOfInitLiq,
        address _token0,
        address _token1,
        uint256 _initLiquidity0, 
        uint256 _initLiquidity1
        ) internal {
        vm.makePersistent(address(this));
        vm.selectFork(L1_FORK_ID);

        forkToDomain[L1_FORK_ID] = L1_DOMAIN;
        forkToChainId[L1_FORK_ID] = L1_CHAIN_ID;
        forkToMailbox[L1_FORK_ID] = address(mailboxL1);

        // deploy dove
        dove01 = Dove(factoryL1.createPair(_token0, _token1));

        // provide initial liquidity
        Minter.mintDAIL1(address(_token0), address(this), _initLiquidity0);
        Minter.mintUSDCL1(address(_token1), address(this), _initLiquidity1);
        //approvals
        L1Token0.approve(address(dove01), type(uint256).max);
        L1Token1.approve(address(dove01), type(uint256).max);
        L1Token0.approve(address(routerL1), type(uint256).max);
        L1Token1.approve(address(routerL1), type(uint256).max);

        (uint256 _toAdd0, uint256 _toAdd1,) =
            routerL1.quoteAddLiquidity(address(L1Token0), address(L1Token1), _initLiquidity0, _initLiquidity1);

        routerL1.addLiquidity(
            _token0,
            _token1,
            _initLiquidity0,
            _initLiquidity1,
            _toAdd0,
            _toAdd1,
            _ownerOfInitLiq,
            type(uint256).max
        );

    }

    function _createPair01(
        uint256 forkID,
        uint32 _domain,
        uint16 _chainID,
        address _dove,
        address _mailbox,
        IL2Factory.SGConfig memory _sgConfig
        ) internal returns (Pair _pair) {
        vm.makePersistent(address(this));
        vm.selectFork(forkID);

        _pair = Pair(factoryL2.createPair(
                address(L2Token1), 
                address(L2Token0), 
                _sgConfig, 
                address(L1Token0), 
                address(L1Token1),
                _dove
            )
        );

        forkToDomain[forkID] = _domain;
        forkToChainId[forkID] = _chainID;
        forkToPair[forkID] = address(_pair);
        forkToMailbox[forkID] = _mailbox;

    }

    function _addBridgePoly(address _dove) internal {
        vm.selectFork(L1_FORK_ID);
        // polygon
        vm.broadcast(address(factoryL1));
        IDove(_dove).addStargateTrustedBridge(
            109, 0x9d1B1669c73b033DFe47ae5a0164Ab96df25B944, 0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97
        );
    }

    function _addRemotePoly(address _dove, address _pair) internal {
        vm.selectFork(L1_FORK_ID);
        // polygon
        vm.broadcast(address(factoryL1));
        IDove(_dove).addTrustedRemote(L2_DOMAIN, bytes32(uint256(uint160(address(_pair)))));
    }

}