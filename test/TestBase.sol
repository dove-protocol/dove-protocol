pragma solidity ^0.8.15;

import {TestUtils} from "./utils/TestUtils.sol";
import {Vm} from "forge-std/Vm.sol";
import {Minter} from "./utils/Minter.sol";

import {Dove} from "../src/L1/Dove.sol";
import {IDove} from "../src/L1/interfaces/IDove.sol";
import {Fountain} from "../src/L1/Fountain.sol";
import {L1Factory} from "../src/L1/L1Factory.sol";
import {L1Router} from "../src/L1/L1Router.sol";
import {SGHyperlaneConverter} from "../src/L1/SGHyperlaneConverter.sol";

import {Pair} from "../src/L2/Pair.sol";
import {FeesAccumulator} from "../src/L2/FeesAccumulator.sol";
import {L2Factory} from "../src/L2/L2Factory.sol";
import {IL2Factory} from "../src/L2/interfaces/IL2Factory.sol";
import {L2Router} from "../src/L2/L2Router.sol";
import {Voucher} from "../src/L2/Voucher.sol";

import {ERC20Mock} from "./mocks/ERC20Mock.sol";
import {InterchainGasPaymasterMock} from "./mocks/InterchainGasPaymasterMock.sol";
import {MailboxMock} from "./mocks/MailboxMock.sol";
import {TypeCasts} from "src/hyperlane/TypeCasts.sol";

import {ILayerZeroEndpoint} from "./utils/ILayerZeroEndpoint.sol";
import {LayerZeroPacket} from "./utils/LZPacket.sol";

import {ProtocolActions} from "./utils/ProtocolActions.sol";

contract TestBase is ProtocolActions, Minter {
    // ----------------------------------------------------------------------------------------------------------
    // CONSTANTS, VARIABLES, MAPPINGS, ADDRESSES, CONTRACTS
    // ----------------------------------------------------------------------------------------------------------

    /// constants
    // time
    uint256 internal constant ONE_DAY = 1 days;
    uint256 internal constant ONE_MONTH = ONE_YEAR / 12;
    uint256 internal constant ONE_YEAR = 365 days;
    uint256 internal start; // start ts set in constructor
    // L1
    address constant L1SGRouter = 0x8731d54E9D02c286767d56ac03e8037C07e01e98;
    InterchainGasPaymasterMock internal gasMasterL1;
    MailboxMock internal mailboxL1;
    ILayerZeroEndpoint internal lzEndpointL1;
    ERC20Mock L1Token0;
    ERC20Mock L1Token1;
    // L2
    address constant L2SGRouter = 0x45A01E4e04F14f7A4a6702c74187c5F6222033cd;
    InterchainGasPaymasterMock internal gasMasterL2;
    MailboxMock internal mailboxL2;
    ILayerZeroEndpoint internal lzEndpointL2;
    ERC20Mock L2Token0;
    ERC20Mock L2Token1;

    /// L1 factory deployer
    address internal pauser;

    /// Helper Mappings
    // constant mappings, set alongside deployed factories on a given forkID
    mapping(uint256 => uint32) forkToDomain;
    mapping(uint256 => uint16) forkToChainId;
    mapping(uint256 => address) forkToMailbox;
    mapping(uint256 => address) forkToRouter;
    // dynamic mappings, set alongside pair deployment
    mapping(uint256 => mapping(bytes32 => address)) forkToPair;

    /// L1 (Ethereum)
    L1Factory internal factoryL1;
    L1Router internal routerL1;
    Dove internal dove01;
    // TODO: add several doves
    Fountain internal fountain;

    /// L2 (Polygon)
    L2Factory internal factoryL2;
    L2Router internal routerL2;
    Pair internal pair01Poly;
    // TODO: add more than 1 pair per chain
    FeesAccumulator internal feesAccumulator;
    Voucher internal voucher;

    /// TODO: more chains than just polygon

    /// Fork/Chain IDs
    uint256 L1_FORK_ID; // Ethereum
    uint256 L2_FORK_ID; // Polygon
    uint16 constant L1_CHAIN_ID = 101;
    uint16 constant L2_CHAIN_ID = 109;
    uint32 constant L1_DOMAIN = 1;
    uint32 constant L2_DOMAIN = 137;

    /// RPCs
    string RPC_ETH_MAINNET = vm.envString("ETH_MAINNET_RPC_URL");
    string RPC_POLYGON_MAINNET = vm.envString("POLYGON_MAINNET_RPC_URL");

    // ----------------------------------------------------------------------------------------------------------
    // Base Setup, Deploy DAI & USDC DOVE/PAIR | Chains: Polygon
    // ----------------------------------------------------------------------------------------------------------
    function setUp() public virtual {
        vm.makePersistent(address(this));
        // set fork id constants for all chains
        _setForks();
        vm.selectFork(L1_FORK_ID);
        // set token constants on all chains
        _setPairTokens01();
        // create factories on all chains
        _createFactories();
        // create Dove01 with DAI & USDC, TestBase owns initial liq
        _createDove(
            dove01, // empty dove
            address(L1Token0), // DAI
            address(L1Token1), // USDC
            10 ** 60, // token 0 initial amount, 10M
            10 ** 36 // token 1 initial amount, 10M
        );
        vm.label(address(dove01), "DOVE: DAI|USDC");
        // add sg bridges to deployed dove(s)
        _addBridgePoly(address(dove01));
        // SGConfig for pairs containing DAI & USDC
        IL2Factory.SGConfig memory sgConfig01 =
            IL2Factory.SGConfig({srcPoolId0: 1, dstPoolId0: 1, srcPoolId1: 3, dstPoolId1: 3});
        // create pair for DAI/USDC on Polygon/L2_FORK_ID
        pair01Poly = _createPair(
            L2_FORK_ID,
            L2_DOMAIN,
            L2_CHAIN_ID,
            address(L2Token0),
            address(L2Token1),
            address(dove01),
            address(mailboxL2),
            address(factoryL2),
            sgConfig01
        );
        vm.label(address(pair01Poly), "PAIR-01-POLY");
        // add pairs as trusted remotes
        _addRemote(address(dove01), address(pair01Poly), L2_DOMAIN);
        // test suite creation timestamp
        start = block.timestamp;
    }

    // ----------------------------------------------------------------------------------------------------------
    // Initialize Functions (Forks, Tokens, and Factories)
    // ----------------------------------------------------------------------------------------------------------

    /// CREATE FORKS

    // Mainnet & Polygon
    function _setForks() internal {
        L1_FORK_ID = vm.createFork(RPC_ETH_MAINNET, 16299272);
        L2_FORK_ID = vm.createFork(RPC_POLYGON_MAINNET, 16299272);
    }

    /// CREATE TOKENS

    // DAI & USDC (can add/remove layers) Currently: Mainnet, Polygon(L2)
    function _setPairTokens01() internal {
        L1Token0 = ERC20Mock(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI
        L1Token1 = ERC20Mock(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC

        L2Token0 = ERC20Mock(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174); // USDC
        L2Token1 = ERC20Mock(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063); // DAI
    }

    /// DEPLOY CONFIGURED FACTORY CONTRACTS

    // Deploy Factories
    // TODO: break down factory deployment by each forkID?
    function _createFactories() internal {
        vm.makePersistent(address(this));
        vm.selectFork(L1_FORK_ID);

        gasMasterL1 = new InterchainGasPaymasterMock();
        mailboxL1 = new MailboxMock(L1_DOMAIN);
        lzEndpointL1 = ILayerZeroEndpoint(0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675);

        forkToDomain[L1_FORK_ID] = L1_DOMAIN;
        forkToChainId[L1_FORK_ID] = L1_CHAIN_ID;
        forkToMailbox[L1_FORK_ID] = address(mailboxL1);

        factoryL1 = new L1Factory(address(gasMasterL1), address(mailboxL1), L1SGRouter);
        routerL1 = new L1Router(address(factoryL1));
        pauser = address(this);

        vm.selectFork(L2_FORK_ID);

        gasMasterL2 = new InterchainGasPaymasterMock();
        mailboxL2 = new MailboxMock(L2_DOMAIN);
        lzEndpointL2 = ILayerZeroEndpoint(0x3c2269811836af69497E5F486A85D7316753cf62);

        factoryL2 = new L2Factory(address(gasMasterL2), address(mailboxL2), L2SGRouter, L1_CHAIN_ID, L1_DOMAIN);
        routerL2 = new L2Router(address(factoryL2));

        forkToDomain[L2_FORK_ID] = L2_DOMAIN;
        forkToChainId[L2_FORK_ID] = L2_CHAIN_ID;
        forkToMailbox[L2_FORK_ID] = address(mailboxL2);
        forkToRouter[L2_FORK_ID] = address(routerL2);
    }

    // ----------------------------------------------------------------------------------------------------------
    // Deployer Functions
    // ----------------------------------------------------------------------------------------------------------

    /// DEPLOY CONFIGURED DOVE CONTRACT(S)

    /// Create a Dove contract for the input tokens, and have TestBase take ownership of the initial liquidity provided
    function _createDove(Dove _dove, address _token0, address _token1, uint256 _initLiquidity0, uint256 _initLiquidity1)
        internal
    {
        vm.makePersistent(address(this));
        vm.selectFork(L1_FORK_ID);

        // deploy dove
        _dove = Dove(factoryL1.createPair(_token0, _token1));

        // provide initial liquidity
        Minter.mintDAIL1(address(_token0), address(this), _initLiquidity0);
        Minter.mintUSDCL1(address(_token1), address(this), _initLiquidity1);
        //approvals
        L1Token0.approve(address(_dove), type(uint256).max);
        L1Token1.approve(address(_dove), type(uint256).max);
        L1Token0.approve(address(routerL1), type(uint256).max);
        L1Token1.approve(address(routerL1), type(uint256).max);

        (uint256 _toAdd0, uint256 _toAdd1,) =
            routerL1.quoteAddLiquidity(address(L1Token0), address(L1Token1), _initLiquidity0, _initLiquidity1);

        routerL1.addLiquidity(
            _token0, _token1, _initLiquidity0, _initLiquidity1, _toAdd0, _toAdd1, address(this), type(uint256).max
        );
    }

    /// TODO: make a deployer function for several doves

    /// DEPLOY CONFIGURED PAIR CONTRACTS

    // Create Pair containing "_token0" & "_token1" on "_forkID" for "_dove"
    function _createPair(
        uint256 _forkID,
        uint32 _domain,
        uint16 _chainID,
        address _token0,
        address _token1,
        address _dove,
        address _mailbox,
        address _factory,
        IL2Factory.SGConfig memory _sgConfig
    ) internal returns (Pair _pair) {
        vm.makePersistent(address(this));
        vm.selectFork(_forkID);

        _pair = Pair(L2Factory(_factory).createPair(_token1, _token0, _sgConfig, _token0, _token1, _dove));

        //bytes32 x = keccak256(abi.encode(_token0, _token1));
        forkToPair[_forkID][keccak256(abi.encode(_token0, _token1))] = address(_pair);
    }

    /// TODO: make a deployer function for several doves

    // ----------------------------------------------------------------------------------------------------------
    // ADD TRUSTED STARGATE BRIDGES & TRUSTED REMOTES/PAIRS
    // ----------------------------------------------------------------------------------------------------------

    // Add Polygon SG bridge for "_dove"
    function _addBridgePoly(address _dove) internal {
        vm.selectFork(L1_FORK_ID);
        // polygon
        vm.broadcast(address(factoryL1));
        IDove(_dove).addStargateTrustedBridge(
            109, 0x9d1B1669c73b033DFe47ae5a0164Ab96df25B944, 0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97
        );
    }

    // Add "_pair" from "_domain" as trusted remote to "_dove"
    function _addRemote(address _dove, address _pair, uint32 _domain) internal {
        vm.selectFork(L1_FORK_ID);
        // polygon
        vm.broadcast(address(factoryL1));
        IDove(_dove).addTrustedRemote(_domain, bytes32(uint256(uint160(address(_pair)))));
    }

    // ----------------------------------------------------------------------------------------------------------
    // Syncing Functions (SyncToL2, SyncToL1)
    // ----------------------------------------------------------------------------------------------------------

    /// Sync "_dove" to "_pair" on "_toForkID"
    // sync a dove to any pair across all chains
    // TODO: Add in a value input parameter for syncL2 to remove need for (1 ether) constant
    function _syncDoveToPair(uint256 _toForkID, address _dove, address _pair) internal {
        vm.selectFork(L1_FORK_ID);
        vm.recordLogs();
        IDove(_dove).syncL2{value: 1 ether}(forkToChainId[_toForkID], _pair);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Packet event with payload should be the last one
        (address sender, bytes memory payload) = abi.decode(logs[logs.length - 1].data, (address, bytes));
        // switch fork
        vm.selectFork(_toForkID);
        vm.broadcast(forkToMailbox[_toForkID]);
        Pair(_pair).handle(L1_DOMAIN, TypeCasts.addressToBytes32(sender), payload);
    }

    /// Standard Sync To L1
    // sync "_pair" to "_dove" using standard ordering
    function _standardSyncToL1(uint256 _fromForkID, address _dove, address _pair) internal {
        uint256[] memory order = new uint[](4);
        order[0] = 0;
        order[1] = 1;
        order[2] = 2;
        order[3] = 3;

        _syncPairToDove(
            _pair, _dove, _fromForkID, order, _handleSGMessage, _handleSGMessage, _handleHLMessage, _handleHLMessage
        );
    }

    /// Sync any pair across all chains to any dove on L1
    // allows for standard or non-standard ordering of L2 => L1 syncing
    function _syncPairToDove(
        address _pair,
        address _dove,
        uint256 _fromForkID,
        uint256[] memory order,
        function(uint256, address, bytes memory) internal one,
        function(uint256, address, bytes memory) internal two,
        function(uint256, address, bytes memory) internal three,
        function(uint256, address, bytes memory) internal four
    ) internal {
        vm.selectFork(_fromForkID);

        vm.recordLogs();
        // TODO: Make value of transaction agnostic to network it is being sent from
        // reminder it's not ether but MATIC
        Pair(_pair).syncToL1{value: 800 ether}(200 ether, 200 ether);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // to find LZ events
        uint256[2] memory LZEventsIndexes =
            _findSyncingEvents(logs, 0xe9bded5f24a4168e4f3bf44e00298c993b22376aad8c58c7dda9718a54cbea82);
        // to find mock mailbox events
        uint256[2] memory HLEventsIndexes =
            _findSyncingEvents(logs, 0x3b31784f245377d844a88ed832a668978c700fd9d25d80e8bf5ef168c6bffa20);

        // first two payloads are LZ
        // last two are HL
        bytes[] memory payloads = new bytes[](4);
        payloads[0] = abi.decode(logs[LZEventsIndexes[0]].data, (bytes));
        payloads[1] = abi.decode(logs[LZEventsIndexes[1]].data, (bytes));
        payloads[2] = logs[HLEventsIndexes[0]].data;
        payloads[3] = logs[HLEventsIndexes[1]].data;

        one(_fromForkID, _dove, payloads[order[0]]);
        two(_fromForkID, _dove, payloads[order[1]]);
        three(_fromForkID, _dove, payloads[order[2]]);
        four(_fromForkID, _dove, payloads[order[3]]);
    }

    // ----------------------------------------------------------------------------------------------------------
    // Swap Functions
    // ----------------------------------------------------------------------------------------------------------

    /// swap "_inputToken" on "_forkID" using "_pair"
    function _swapSimple(
        uint256 _forkID,
        address _pair,
        address _swapperAddr,
        address _inputToken,
        uint256 _inputAmount
    ) internal returns (uint256[] memory amounts) {
        vm.selectFork(_forkID);

        Pair _Pair = Pair(_pair);

        if(_inputToken == _Pair.token0()) {
            uint256 _outputAmount = _Pair.getAmountOut(_inputAmount, _Pair.token0());
            amounts = L2Router(forkToRouter[_forkID]).swapExactTokensForTokensSimple(
                _inputAmount, _outputAmount, _Pair.token0(), _Pair.token1(), _swapperAddr, block.timestamp + 1000
            );
        } else {
            uint256 _outputAmount = _Pair.getAmountOut(_inputAmount, _Pair.token1());
            amounts = L2Router(forkToRouter[_forkID]).swapExactTokensForTokensSimple(
                _inputAmount, _outputAmount, _Pair.token1(), _Pair.token0(), _swapperAddr, block.timestamp + 1000
            );
        }
    }

    /// swap "_inputToken" on "_forkID" using "_pair"
    function _swapDouble(
        uint256 _forkID,
        address _pair,
        address _swapperAddr,
        address _inputToken0,
        address _inputToken1,
        uint256 _inputAmount0,
        uint256 _inputAmount1
    ) internal returns(uint256[] memory swap0Amounts, uint256[] memory swap1Amounts) {
        vm.selectFork(_forkID);

        Pair _Pair = Pair(_pair);

        if(_inputToken0 == _Pair.token0()) {
            uint256 _outputAmount = _Pair.getAmountOut(_inputAmount0, _Pair.token0());
            swap0Amounts = L2Router(forkToRouter[_forkID]).swapExactTokensForTokensSimple(
                _inputAmount0, _outputAmount, _Pair.token0(), _Pair.token1(), _swapperAddr, block.timestamp + 1000
            );
        } else {
            uint256 _outputAmount = _Pair.getAmountOut(_inputAmount0, _Pair.token1());
            swap0Amounts = L2Router(forkToRouter[_forkID]).swapExactTokensForTokensSimple(
                _inputAmount0, _outputAmount, _Pair.token1(), _Pair.token0(), _swapperAddr, block.timestamp + 1000
            );
        }

        if(_inputToken1 == _Pair.token1()) {
            uint256 _outputAmount = _Pair.getAmountOut(_inputAmount1, _Pair.token1());
            swap1Amounts = L2Router(forkToRouter[_forkID]).swapExactTokensForTokensSimple(
                _inputAmount1, _outputAmount, _Pair.token1(), _Pair.token0(), _swapperAddr, block.timestamp + 1000
            );
        } else {
            uint256 _outputAmount = _Pair.getAmountOut(_inputAmount1, _Pair.token0());
            swap1Amounts = L2Router(forkToRouter[_forkID]).swapExactTokensForTokensSimple(
                _inputAmount1, _outputAmount, _Pair.token0(), _Pair.token1(), _swapperAddr, block.timestamp + 1000
            );
        }
    }

    function _k(uint256 x, uint256 y) internal view returns (uint256) {
        uint256 _x = (x * 1e18) / uint64(10 ** 18);
        uint256 _y = (y * 1e18) / uint64(10 ** 6);
        uint256 _a = (_x * _y) / 1e18;
        uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
        return (_a * _b) / 1e18; // x3y+y3x >= k
    }

    // ----------------------------------------------------------------------------------------------------------
    // Voucher Actions (burn, YEEET)
    // ----------------------------------------------------------------------------------------------------------

    /// Burn/send "user" vouchers (L2 tokens) from "_forkID" to "_dove", at amounts "_amount0" & "_amount1"
    function _burnVouchers(
        uint256 _forkID,
        address _dove,
        address user,
        address _pair,
        uint256 _amount0,
        uint256 _amount1
    ) internal {
        vm.selectFork(_forkID);
        vm.recordLogs();
        vm.broadcast(user);
        Pair(_pair).burnVouchers(_amount0, _amount1);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        // should be second long
        (address sender, bytes memory HLpayload) = abi.decode(logs[1].data, (address, bytes));
        vm.selectFork(L1_FORK_ID);
        vm.broadcast(address(mailboxL1));
        Dove(_dove).handle(forkToDomain[_forkID], TypeCasts.addressToBytes32(sender), HLpayload);
    }

    /// YEEEEEEET
    function _yeetVouchers(address _pair, address user, uint256 _amount0, uint256 _amount1) internal {
        vm.startBroadcast(user);
        Pair(_pair).voucher0().approve(_pair, type(uint256).max);
        Pair(_pair).voucher1().approve(_pair, type(uint256).max);
        Pair(_pair).yeetVouchers(_amount0, _amount1);
        vm.stopBroadcast();
    }

    // ---------------------------------------------------
    //  MISC HELPER FUNCTIONS
    // ---------------------------------------------------

    function _handleSGMessage(uint256 _fromForkID, address _dove, bytes memory payload) internal {
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

    function _handleHLMessage(uint256 _fromForkID, address _dove, bytes memory payload) internal {
        vm.selectFork(L1_FORK_ID);
        (address sender, bytes memory HLpayload) = abi.decode(payload, (address, bytes));
        vm.broadcast(address(mailboxL1));
        Dove(_dove).handle(forkToDomain[_fromForkID], TypeCasts.addressToBytes32(sender), HLpayload);
    }

    /// Find Layer0 and HL Mailbox events for syncing Pairs to Mainnet
    function _findSyncingEvents(Vm.Log[] memory logs, bytes32 topic) internal returns (uint256[2] memory indexes) {
        bool useIndex0 = true;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == topic) {
                if (useIndex0) {
                    indexes[0] = i;
                    useIndex0 = false;
                } else {
                    indexes[1] = i;
                    break;
                }
            }
        }
    }
}
