// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

import {FeesDistributor} from "./FeesDistributor.sol";
import {Fountain} from "./Fountain.sol";
import {SGHyperlaneConverter} from "./SGHyperlaneConverter.sol";

import "../hyperlane/TypeCasts.sol";

import "./interfaces/IStargateReceiver.sol";
import "../hyperlane/HyperlaneClient.sol";

import "../MessageType.sol";

contract Dove is IStargateReceiver, Owned, HyperlaneClient, ERC20, ReentrancyGuard {
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event Fees(uint256 indexed srcDomain, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Claim(address indexed sender, address indexed recipient, uint256 amount0, uint256 amount1);
    event Sync(uint256 reserve0, uint256 reserve1);
    event Bridged(address token, uint256 amount);
    /*###############################################################
                            STRUCTS
    ###############################################################*/

    struct PartialSync {
        address token;
        uint256 pairBalance; // L2 pair balance
        uint256 earmarkedAmount; // tokens to earmark
    }

    /*###############################################################
                            STORAGE
    ###############################################################*/

    uint256 internal constant MINIMUM_LIQUIDITY = 10 ** 3;

    address public stargateRouter;

    address public token0;
    address public token1;

    uint256 public reserve0;
    uint256 public reserve1;

    FeesDistributor public feesDistributor;
    Fountain public fountain;

    /// @notice earmarked tokens
    mapping(uint32 => uint256) public marked0;
    mapping(uint32 => uint256) public marked1;
    /// @notice domain id [hyperlane] => PartialSync
    mapping(uint32 => PartialSync) public partialSyncs;

    mapping(uint32 => bytes32) public trustedRemoteLookup;
    mapping(uint16 => bytes) public sgTrustedBridge;

    mapping(uint32 => uint256) internal lastBridged0;
    mapping(uint32 => uint256) internal lastBridged1;

    function addTrustedRemote(uint32 origin, bytes32 sender) external onlyOwner {
        trustedRemoteLookup[origin] = sender;
    }

    function addStargateTrustedBridge(uint16 chainId, address remote, address local) external onlyOwner {
        sgTrustedBridge[chainId] = abi.encodePacked(remote, local);
    }

    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/

    constructor(address _token0, address _token1, address _hyperlaneGasMaster, address _mailbox, address _sgRouter)
        ERC20("Dove", "DVE", 18)
        HyperlaneClient(_hyperlaneGasMaster, _mailbox, msg.sender)
    {
        token0 = _token0;
        token1 = _token1;
        stargateRouter = _sgRouter;

        feesDistributor = new FeesDistributor(_token0, _token1);
        fountain = new Fountain(_token0, _token1);
    }

    /*###############################################################
                            LIQUIDITY LOGIC
    ###############################################################*/

    function _update(uint256 balance0, uint256 balance1, uint256 _reserve0, uint256 _reserve1) internal {
        reserve0 = balance0;
        reserve1 = balance1;
        emit Sync(reserve0, reserve1);
    }

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        uint256 _balance0 = ERC20(token0).balanceOf(address(this));
        uint256 _balance1 = ERC20(token1).balanceOf(address(this));
        uint256 _amount0 = _balance0 - _reserve0;
        uint256 _amount1 = _balance1 - _reserve1;

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = FixedPointMathLib.sqrt(_amount0 * _amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            uint256 a = _amount0 * _totalSupply / _reserve0;
            uint256 b = _amount1 * _totalSupply / _reserve1;
            liquidity = a < b ? a : b;
        }
        require(liquidity > 0, "ILM");
        _mint(to, liquidity);

        _update(_balance0, _balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, _amount0, _amount1);
    }

    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        (ERC20 _token0, ERC20 _token1) = (ERC20(token0), ERC20(token1));
        uint256 _balance0 = _token0.balanceOf(address(this));
        uint256 _balance1 = _token1.balanceOf(address(this));
        uint256 _liquidity = balanceOf[address(this)];

        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = _liquidity * _balance0 / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = _liquidity * _balance1 / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, "ILB"); // BaseV1: INSUFFICIENT_LIQUIDITY_BURNED
        _burn(address(this), _liquidity);

        SafeTransferLib.safeTransfer(_token0, to, amount0);
        SafeTransferLib.safeTransfer(_token1, to, amount1);
        _balance0 = _token0.balanceOf(address(this));
        _balance1 = _token1.balanceOf(address(this));

        _update(_balance0, _balance1, _reserve0, _reserve1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /*###############################################################
                            SYNCING LOGIC
    ###############################################################*/

    function sgReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint256, /*_nonce*/
        address _token,
        uint256 _bridgedAmount,
        bytes calldata
    ) external override {
        require(msg.sender == stargateRouter, "NOT STARGATE");
        require(keccak256(_srcAddress) == keccak256(sgTrustedBridge[_srcChainId]), "NOT TRUSTED");
        uint32 domain = SGHyperlaneConverter.sgToHyperlane(_srcChainId);
        if (_token == token0) {
            lastBridged0[domain] = _bridgedAmount;
        } else if (_token == token1) {
            lastBridged1[domain] = _bridgedAmount;
        }
        emit Bridged(_token, _bridgedAmount);
    }

    function syncFromL2(uint32 origin, address token, uint256 earmarkedDelta, uint256 pairBalance) internal {
        // check if already partial sync
        // @note Maybe enforce check that second partial sync is "pair" of first one
        PartialSync memory partialSync = partialSyncs[origin];
        if (partialSync.token == address(0)) {
            partialSyncs[origin] = PartialSync(token, pairBalance, earmarkedDelta);
        } else {
            // can proceed with full sync
            if (token == token0) {
                _syncFromL2(origin, pairBalance, partialSync.pairBalance, earmarkedDelta, partialSync.earmarkedAmount);
            } else {
                _syncFromL2(origin, partialSync.pairBalance, pairBalance, partialSync.earmarkedAmount, earmarkedDelta);
            }
            // reset
            delete partialSyncs[origin];
        }
    }

    function handle(uint32 origin, bytes32 sender, bytes calldata payload) external onlyMailbox {
        // check if message is from trusted remote
        require(trustedRemoteLookup[origin] == sender, "NOT TRUSTED");
        uint256 messageType = abi.decode(payload, (uint256));
        if (messageType == MessageType.BURN_VOUCHERS) {
            // receive both token addresses and amounts
            (, address user, address token0Address, uint256 amount0, uint256 amount1) = abi.decode(payload, (uint256, address, address, uint256, uint256));
            _completeVoucherBurns(origin, user, token0Address, amount0, amount1);
        } else if (messageType == MessageType.SYNC_TO_L1) {
            (, address token, uint256 earmarkedDelta, uint256 pairBalance) =
                abi.decode(payload, (uint256, address, uint256, uint256));
            syncFromL2(origin, token, earmarkedDelta, pairBalance);
        }
    }

    function syncL2(uint32 destinationDomain, address amm) external payable {
        bytes memory payload = abi.encode(MessageType.SYNC_TO_L2, token0, reserve0, reserve1);
        bytes32 id = mailbox.dispatch(destinationDomain, TypeCasts.addressToBytes32(amm), payload);
        // pay for gas
        hyperlaneGasMaster.payGasFor{value: msg.value}(id, destinationDomain);
    }

    /*###############################################################
                            INTERNAL FUNCTIONS
    ###############################################################*/

    /// @notice Completes a voucher burn initiated on the L2.
    /// @dev Checks if user is able to burn or not should be done on L2 beforehand.
    /// @param srcDomain The domain id of the remote chain.
    /// @param user The user who initiated the burn.
    /// @param token0Address The address of the token0.
    /// @param amount0 The quantity of local token0 tokens.
    /// @param amount1 The quantity of local token1 tokens.
    function _completeVoucherBurns(uint32 srcDomain, address token0Address, address user, uint256 amount0, uint256 amount1) internal {
        // update earmarked tokens
        if(token0Address == token0) {
            marked0[srcDomain] -= amount0;
            marked1[srcDomain] -= amount1;
            fountain.squirt(user, amount0, amount1);

        } else {
            marked0[srcDomain] -= amount1;
            marked1[srcDomain] -= amount0;
            fountain.squirt(user, amount1, amount0);
        }
    }

    /// @notice Syncing implies bridging the tokens from the L2 back to the L1.
    /// @notice These tokens are simply added back to the reserves.
    /// @dev    This should be an authenticated call, only callable by the operator.
    /// @dev    The sync should be followed by a sync on the L2.
    function _syncFromL2(
        uint32 srcDomain,
        uint256 pairBalance0,
        uint256 pairBalance1,
        uint256 earmarkedDelta0,
        uint256 earmarkedDelta1
    ) internal {
        (ERC20 _token0, ERC20 _token1) = (ERC20(token0), ERC20(token1));
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        {
            reserve0 = _reserve0 + pairBalance0 - earmarkedDelta0;
            reserve1 = _reserve1 + pairBalance1 - earmarkedDelta1;
            marked0[srcDomain] += earmarkedDelta0;
            marked1[srcDomain] += earmarkedDelta1;
            // put earmarked tokens on the side
            SafeTransferLib.safeTransfer(_token0, address(fountain), earmarkedDelta0);
            SafeTransferLib.safeTransfer(_token1, address(fountain), earmarkedDelta1);
        }
        uint256 balance0 = _token0.balanceOf(address(this));
        uint256 balance1 = _token1.balanceOf(address(this));
        {
            uint256 fees0 = lastBridged0[srcDomain] - pairBalance0;
            uint256 fees1 = lastBridged1[srcDomain] - pairBalance1;
            emit Fees(srcDomain, fees0, fees1);
            // uint256 balance0Adjusted = balance0 - fees0;
            // uint256 balance1Adjusted = balance1 - fees1;
            // check curve ?????
            // cleanup
            delete lastBridged0[srcDomain];
            delete lastBridged1[srcDomain];
            
        }
        _update(balance0, balance1, _reserve0, _reserve1);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        return super.transferFrom(from, to, amount);
    }

    /*###############################################################
                            VIEW FUNCTIONS
    ###############################################################*/

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }
}
