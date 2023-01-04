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
    event Updated(uint256 reserve0, uint256 reserve1);
    event Bridged(address token, uint256 amount);
    event SyncPending(uint256 indexed srcDomain, uint256 syncID);
    event SyncFinalized(
        uint256 indexed srcDomain,
        uint256 syncID,
        uint256 pairBalance0,
        uint256 pairBalance1,
        uint256 earmarkedAmount0,
        uint256 earmarkedAmount1
    );
    /*###############################################################
                            STRUCTS
    ###############################################################*/

    struct PartialSync {
        address token;
        uint256 pairBalance; // L2 pair balance
        uint256 earmarkedAmount; // tokens to earmark
    }

    struct Sync {
        PartialSync partialSync1;
        PartialSync partialSync2;
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
    mapping(uint32 => mapping(uint256 => Sync)) public syncs;

    mapping(uint32 => bytes32) public trustedRemoteLookup;
    mapping(uint16 => bytes) public sgTrustedBridge;

    mapping(uint32 => mapping(uint256 => uint256)) internal lastBridged0;
    mapping(uint32 => mapping(uint256 => uint256)) internal lastBridged1;

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
        emit Updated(reserve0, reserve1);
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
        bytes calldata data
    ) external override {
        require(msg.sender == stargateRouter, "NOT STARGATE");
        require(keccak256(_srcAddress) == keccak256(sgTrustedBridge[_srcChainId]), "NOT TRUSTED");
        uint256 syncID = abi.decode(data, (uint256));
        uint32 domain = SGHyperlaneConverter.sgToHyperlane(_srcChainId);
        if (_token == token0) {
            lastBridged0[domain][syncID] = _bridgedAmount;
        } else if (_token == token1) {
            lastBridged1[domain][syncID] = _bridgedAmount;
        }
        emit Bridged(_token, _bridgedAmount);
    }

    function handle(uint32 origin, bytes32 sender, bytes calldata payload) external onlyMailbox {
        // check if message is from trusted remote
        require(trustedRemoteLookup[origin] == sender, "NOT TRUSTED");
        uint256 messageType = abi.decode(payload, (uint256));
        if (messageType == MessageType.BURN_VOUCHERS) {
            // receive both amounts and a single address to determine ordering
            (
                ,
                address user,
                address token,
                uint256 amount0,
                uint256 amount1
            ) = abi.decode(payload, (uint256, address, address, uint256, uint256));
            _completeVoucherBurns(origin, user, token, amount0, amount1);
        } else if (messageType == MessageType.SYNC_TO_L1) {
            (
                ,
                uint256 syncID,
                address token,
                uint256 earmarkedDelta,
                uint256 pairBalance
            ) = abi.decode(payload, (uint256, uint256, address, uint256, uint256));
            _syncFromL2(origin, syncID, token, earmarkedDelta, pairBalance);
        }
    }

    function syncL2(uint32 destinationDomain, address amm) external payable {
        bytes memory payload = abi.encode(MessageType.SYNC_TO_L2, token0, reserve0, reserve1);
        bytes32 id = mailbox.dispatch(destinationDomain, TypeCasts.addressToBytes32(amm), payload);
        // pay for gas
        hyperlaneGasMaster.payGasFor{value: msg.value}(id, destinationDomain);
    }

    function finalizeSyncFromL2(uint32 originDomain, uint256 syncID) external {
        require(lastBridged0[originDomain][syncID] > 0 && lastBridged1[originDomain][syncID] > 0, "NO SG SWAPS");
        Sync memory sync = syncs[originDomain][syncID];
        (
            PartialSync memory partialSync0,
            PartialSync memory partialSync1
        ) = sync.partialSync1.token == token0 ? (sync.partialSync1, sync.partialSync2) : (sync.partialSync2, sync.partialSync1);
        _finalizeSyncFromL2(originDomain, syncID, partialSync0, partialSync1);
    }

    /*###############################################################
                            INTERNAL FUNCTIONS
    ###############################################################*/

    /// @notice Completes a voucher burn initiated on the L2.
    /// @dev Checks if user is able to burn or not should be done on L2 beforehand.
    /// @param srcDomain The domain id of the remote chain.
    /// @param user The user who initiated the burn.
    /// @param token The address of the token0 for reference in ordering.
    /// @param amount0 The quantity of local token0 tokens.
    /// @param amount1 The quantity of local token1 tokens.
    function _completeVoucherBurns(uint32 srcDomain, address user, address token, uint256 amount0, uint256 amount1) internal {
        // update earmarked tokens
        if(token == token0) {
            marked0[srcDomain] -= amount0;
            marked1[srcDomain] -= amount1;
            fountain.squirt(user, amount0, amount1);

        } else {
            marked0[srcDomain] -= amount1;
            marked1[srcDomain] -= amount0;
            fountain.squirt(user, amount1, amount0);
        }
    }

    function _syncFromL2(uint32 origin, uint256 syncID, address token, uint256 earmarkedDelta, uint256 pairBalance) internal {
        Sync memory sync = syncs[origin][syncID];
        // sync.partialSync1 should always be the first one to be set, regardless
        // if it's token0 or token1 being bridged
        if (sync.partialSync1.token == address(0)) {
            syncs[origin][syncID].partialSync1 = PartialSync(token, pairBalance, earmarkedDelta);
        } else {
            // can proceed with full sync since we got the two HyperLane messages
            // have to check if SG swaps are completed
            if (lastBridged0[origin][syncID] > 0 && lastBridged1[origin][syncID] > 0) {
                if (token == token0) {
                    _finalizeSyncFromL2(origin, syncID, sync.partialSync1, PartialSync(token, pairBalance, earmarkedDelta));
                } else {
                    _finalizeSyncFromL2(origin, syncID, PartialSync(token, pairBalance, earmarkedDelta), sync.partialSync1);
                }
                // reset
                delete syncs[origin][syncID];
            } else {
                // otherwise means there is at least one SG swap that hasn't completed yet
                // so we need to store the HL data and execute the sync when the SG swap is done
                syncs[origin][syncID].partialSync2 = PartialSync(token, pairBalance, earmarkedDelta);
                emit SyncPending(origin, syncID);
            }
        }
    }

    /// @notice Syncing implies bridging the tokens from the L2 back to the L1.
    /// @notice These tokens are simply added back to the reserves.
    /// @dev    This should be an authenticated call, only callable by the operator.
    /// @dev    The sync should be followed by a sync on the L2.
    function _finalizeSyncFromL2(
        uint32 srcDomain,
        uint256 syncID,
        PartialSync memory partialSync0,
        PartialSync memory partialSync1
    ) internal {
        (ERC20 _token0, ERC20 _token1) = (ERC20(token0), ERC20(token1));
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        {
            reserve0 = _reserve0 + partialSync0.pairBalance - partialSync0.earmarkedAmount;
            reserve1 = _reserve1 + partialSync1.pairBalance - partialSync1.earmarkedAmount;
            marked0[srcDomain] += partialSync0.earmarkedAmount;
            marked1[srcDomain] += partialSync1.earmarkedAmount;
            // put earmarked tokens on the side
            SafeTransferLib.safeTransfer(ERC20(partialSync0.token), address(fountain), partialSync0.earmarkedAmount);
            SafeTransferLib.safeTransfer(ERC20(partialSync1.token), address(fountain), partialSync1.earmarkedAmount);

            emit SyncFinalized(
                srcDomain,
                syncID,
                partialSync0.pairBalance,
                partialSync1.pairBalance,
                partialSync0.earmarkedAmount,
                partialSync1.earmarkedAmount
            );
        }
        uint256 balance0 = ERC20(partialSync0.token).balanceOf(address(this));
        uint256 balance1 = ERC20(partialSync0.token).balanceOf(address(this));
        {
            emit Fees(
                srcDomain,
                lastBridged0[srcDomain][syncID] - partialSync0.pairBalance,
                lastBridged1[srcDomain][syncID] - partialSync0.pairBalance
            );
            // cleanup
            delete lastBridged0[srcDomain][syncID];
            delete lastBridged1[srcDomain][syncID];
            
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
