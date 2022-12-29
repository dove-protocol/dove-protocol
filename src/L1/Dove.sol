// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

import {FeesDistributor} from "./FeesDistributor.sol";
import {SGHyperlaneConverter} from "./SGHyperlaneConverter.sol";

import "../hyperlane/TypeCasts.sol";

import "./interfaces/IStargateReceiver.sol";
import "../hyperlane/HyperlaneClient.sol";

import "../MessageType.sol";

contract Dove is IStargateReceiver, Owned, HyperlaneClient, ERC20, ReentrancyGuard {
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event Fees(address indexed sender, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Claim(address indexed sender, address indexed recipient, uint256 amount0, uint256 amount1);
    event Sync(uint256 reserve0, uint256 reserve1);
    /*###############################################################
                            STRUCTS
    ###############################################################*/

    struct PartialSync {
        address token;
        uint256 balance; // L2 balance
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

    /// @notice earmarked tokens
    mapping(uint32 => uint256) public marked0;
    mapping(uint32 => uint256) public marked1;
    /// @notice domain id [hyperlane] => PartialSync
    mapping(uint32 => PartialSync) public partialSyncs;

    mapping(uint32 => bytes32) public trustedRemoteLookup;
    mapping(uint16 => bytes) public sgTrustedBridge;

    mapping(uint32 => uint256) internal lastBridged0;
    mapping(uint32 => uint256) internal lastBridged1;

    // index0 and index1 are used to accumulate fees, this is split out from normal trades to keep the swap "clean"
    // this further allows LP holders to easily claim fees for tokens they have/staked
    uint256 public index0 = 0;
    uint256 public index1 = 0;

    // position assigned to each LP to track their current index0 & index1 vs the global position
    mapping(address => uint256) public supplyIndex0;
    mapping(address => uint256) public supplyIndex1;

    // tracks the amount of unclaimed, but claimable tokens off of fees for token0 and token1
    mapping(address => uint256) public claimable0;
    mapping(address => uint256) public claimable1;

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
    }

    /*###############################################################
                            LIQUIDITY LOGIC
    ###############################################################*/

    function claimFeesFor(address recipient) public nonReentrant returns (uint256 claimed0, uint256 claimed1) {
        return _claimFees(recipient);
    }

    function updateAndClaimFeesFor(address recipient) external returns (uint256 claimed0, uint256 claimed1) {
        _updateFor(recipient);
        return _claimFees(recipient);
    }

    function _claimFees(address recipient) internal returns (uint256 claimed0, uint256 claimed1) {
        claimed0 = claimable0[recipient];
        claimed1 = claimable1[recipient];

        claimable0[recipient] = 0;
        claimable1[recipient] = 0;

        feesDistributor.claimFeesFor(recipient, claimed0, claimed1);

        emit Claim(msg.sender, recipient, claimed0, claimed1);
    }

    // this function MUST be called on any balance changes, otherwise can be used to infinitely claim fees
    // Fees are segregated from core funds, so fees can never put liquidity at risk
    function _updateFor(address recipient) internal {
        uint256 _supplied = balanceOf[recipient]; // get LP balance of `recipient`
        if (_supplied > 0) {
            uint256 _supplyIndex0 = supplyIndex0[recipient]; // get last adjusted index0 for recipient
            uint256 _supplyIndex1 = supplyIndex1[recipient];
            uint256 _index0 = index0; // get global index0 for accumulated fees
            uint256 _index1 = index1;
            supplyIndex0[recipient] = _index0; // update user current position to global position
            supplyIndex1[recipient] = _index1;
            uint256 _delta0 = _index0 - _supplyIndex0; // see if there is any difference that need to be accrued
            uint256 _delta1 = _index1 - _supplyIndex1;
            if (_delta0 > 0) {
                uint256 _share = _supplied * _delta0 / 1e18; // add accrued difference for each supplied token
                claimable0[recipient] += _share;
            }
            if (_delta1 > 0) {
                uint256 _share = _supplied * _delta1 / 1e18;
                claimable1[recipient] += _share;
            }
        } else {
            supplyIndex0[recipient] = index0; // new users are set to the default global state
            supplyIndex1[recipient] = index1;
        }
    }

    function _update(uint256 balance0, uint256 balance1, uint256 _reserve0, uint256 _reserve1) internal {
        reserve0 = balance0;
        reserve1 = balance1;
        emit Sync(reserve0, reserve1);
    }

    function mint(address to) external nonReentrant returns (uint256 liquidity) {
        _claimFees(to);
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
        _updateFor(to);
        _mint(to, liquidity);

        _update(_balance0, _balance1, _reserve0, _reserve1);
        emit Mint(msg.sender, _amount0, _amount1);
    }

    function burn(address to) external nonReentrant returns (uint256 amount0, uint256 amount1) {
        _claimFees(to);
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        (ERC20 _token0, ERC20 _token1) = (ERC20(token0), ERC20(token1));
        uint256 _balance0 = _token0.balanceOf(address(this));
        uint256 _balance1 = _token1.balanceOf(address(this));
        uint256 _liquidity = balanceOf[address(this)];

        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = _liquidity * _balance0 / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = _liquidity * _balance1 / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, "ILB"); // BaseV1: INSUFFICIENT_LIQUIDITY_BURNED
        _updateFor(to);
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
    }

    function syncFromL2(uint32 origin, address token, uint256 earmarkedDelta, uint256 balance) internal {
        // check if already partial sync
        // @note Maybe enforce check that second partial sync is "pair" of first one
        PartialSync memory partialSync = partialSyncs[origin];
        if (partialSync.token == address(0)) {
            partialSyncs[origin] = PartialSync(token, balance, earmarkedDelta);
        } else {
            // can proceed with full sync
            if (partialSync.token == token0) {
                _syncFromL2(origin, partialSync.balance, balance, partialSync.earmarkedAmount, earmarkedDelta);
            } else {
                _syncFromL2(origin, balance, partialSync.balance, earmarkedDelta, partialSync.earmarkedAmount);
            }
            // reset
            delete partialSyncs[origin];
        }
    }

    function handle(uint32 origin, bytes32 sender, bytes calldata payload) external onlyInbox {
        // check if message is from trusted remote
        require(trustedRemoteLookup[origin] == sender, "NOT TRUSTED");
        uint256 messageType = abi.decode(payload, (uint256));
        if (messageType == MessageType.BURN_VOUCHER) {
            // token address should be either L1 address of token0 or token1
            (, address token, address user, uint256 amount) = abi.decode(payload, (uint256, address, address, uint256));
            _completeVoucherBurn(origin, token, user, amount);
        } else if (messageType == MessageType.SYNC_TO_L1) {
            (, address token, uint256 earmarkedDelta, uint256 balance) =
                abi.decode(payload, (uint256, address, uint256, uint256));
        }
    }

    function syncL2(uint32 destinationDomain, address amm) external payable {
        bytes memory payload = abi.encode(reserve0, reserve1);
        bytes32 id = mailbox.dispatch(destinationDomain, TypeCasts.addressToBytes32(amm), payload);
        // pay for gas
        hyperlaneGasMaster.payGasFor{value: msg.value}(id, destinationDomain);
    }

    /*###############################################################
                            INTERNAL FUNCTIONS
    ###############################################################*/

    function _update0(uint256 amount) internal {
        SafeTransferLib.safeTransfer(ERC20(token0), address(feesDistributor), amount);
        uint256 _ratio = amount * 1e18 / totalSupply; // 1e18 adjustment is removed during claim
        if (_ratio > 0) {
            index0 += _ratio;
        }
        emit Fees(msg.sender, amount, 0);
    }

    // Accrue fees on token1
    function _update1(uint256 amount) internal {
        SafeTransferLib.safeTransfer(ERC20(token1), address(feesDistributor), amount);
        uint256 _ratio = amount * 1e18 / totalSupply;
        if (_ratio > 0) {
            index1 += _ratio;
        }
        emit Fees(msg.sender, 0, amount);
    }

    /// @notice Completes a voucher burn initiated on the L2.
    /// @dev Checks if user is able to burn or not should be done on L2 beforehand.
    /// @param srcDomain The domain id of the remote chain.
    /// @param token The token contract on the local chain.
    /// @param user The user who initiated the burn.
    /// @param amount The quantity of local _token tokens.
    function _completeVoucherBurn(uint32 srcDomain, address token, address user, uint256 amount) internal {
        require(token == token0 || token == token1, "BURN:INVALID TOKEN");
        // update earmarked tokens
        if (token == token0) {
            marked0[srcDomain] -= amount;
        } else {
            marked1[srcDomain] -= amount;
        }
        ERC20(token).transfer(user, amount);
    }

    /// @notice Syncing implies bridging the tokens from the L2 back to the L1.
    /// @notice These tokens are simply added back to the reserves.
    /// @dev    This should be an authenticated call, only callable by the operator.
    /// @dev    The sync should be followed by a sync on the L2.
    function _syncFromL2(
        uint32 srcDomain,
        uint256 balance0,
        uint256 balance1,
        uint256 earmarkedDelta0,
        uint256 earmarkedDelta1
    ) internal {
        uint256 newReserve0 = reserve0 + balance0 - earmarkedDelta0;
        uint256 newReserve1 = reserve1 + balance1 - earmarkedDelta1;
        // check soemwhere if it respects the curve
        reserve0 = newReserve0;
        reserve1 = newReserve1;
        marked0[srcDomain] += earmarkedDelta0;
        marked1[srcDomain] += earmarkedDelta1;
        // send out fees
        // optimistically, bridged > balance
        uint256 fees0 = lastBridged0[srcDomain] - balance0;
        uint256 fees1 = lastBridged1[srcDomain] - balance1;
        _update0(fees0);
        _update1(fees1);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _updateFor(msg.sender);
        _updateFor(to);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _updateFor(from);
        _updateFor(to);
        return super.transferFrom(from, to, amount);
    }

    /*###############################################################
                            VIEW FUNCTIONS
    ###############################################################*/

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }
}
