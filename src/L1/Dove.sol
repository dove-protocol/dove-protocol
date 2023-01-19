// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

import {Fountain} from "./Fountain.sol";
import {SGHyperlaneConverter} from "./SGHyperlaneConverter.sol";

import "../hyperlane/TypeCasts.sol";

import "./interfaces/IStargateReceiver.sol";
import "./interfaces/IL1Factory.sol";
import "../hyperlane/HyperlaneClient.sol";

import "../MessageType.sol";

contract Dove is IStargateReceiver, Owned, HyperlaneClient, ERC20, ReentrancyGuard {
    /*###############################################################
                            EVENTS
    ###############################################################*/
    event Fees(uint256 indexed srcDomain, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Claim(address indexed recipient, uint256 amount0, uint256 amount1);
    event Updated(uint256 reserve0, uint256 reserve1);
    event Bridged(uint256 indexed srcChainId, uint256 syncId, address token, uint256 amount);
    event SyncPending(uint256 indexed srcDomain, uint256 syncID);
    event SyncFinalized(
        uint256 indexed srcDomain,
        uint256 syncID,
        uint256 pairBalance0,
        uint256 pairBalance1,
        uint256 earmarkedAmount0,
        uint256 earmarkedAmount1
    );
    event BurnClaimCreated(uint256 indexed srcDomain, address indexed user, uint256 amount0, uint256 amount1);

    /*###############################################################
                            ERRORS
    ###############################################################*/
    error InsuffcientLiquidityMinted();
    error InsuffcientLiquidityBurned();
    error NotStargate();
    error NotTrusted();
    error NoStargateSwaps();
    
    /*###############################################################
                            STRUCTS
    ###############################################################*/

    struct PartialSync {
        address token;
        uint256 pairBalance; // L2 pair balance
        uint256 earmarkedAmount; // tokens to earmark
    }

    struct Sync {
        PartialSync partialSyncA;
        PartialSync partialSyncB;
    }

    struct BurnClaim {
        uint256 amount0;
        uint256 amount1;
    }

    /*###############################################################
                            STORAGE
    ###############################################################*/

    uint256 internal constant MINIMUM_LIQUIDITY = 10 ** 3;

    IL1Factory public factory;

    address public token0;
    address public token1;

    uint256 public reserve0;
    uint256 public reserve1;

    Fountain public feesDistributor;
    Fountain public fountain;

    /// @notice domain id [hyperlane] => earmarked tokens
    mapping(uint32 => uint256) public marked0;
    mapping(uint32 => uint256) public marked1;
    mapping(uint32 => mapping(uint256 => Sync)) public syncs;
    mapping(uint32 => mapping(address => BurnClaim)) public burnClaims;

    mapping(uint32 => bytes32) public trustedRemoteLookup;
    mapping(uint16 => bytes) public sgTrustedBridge;

    mapping(uint32 => mapping(uint256 => uint256)) internal lastBridged0;
    mapping(uint32 => mapping(uint256 => uint256)) internal lastBridged1;

    // index0 and index1 are used to accumulate fees, this is split out from normal trades to keep the swap "clean"
    // this further allows LP holders to easily claim fees for tokens they have/staked
    uint256 public index0;
    uint256 public index1;

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

    constructor(address _token0, address _token1, address _hyperlaneGasMaster, address _mailbox)
        ERC20("Dove", "DVE", 18)
        HyperlaneClient(_hyperlaneGasMaster, _mailbox, msg.sender)
    {
        factory = IL1Factory(msg.sender);

        token0 = _token0;
        token1 = _token1;

        feesDistributor = new Fountain(_token0, _token1);
        fountain = new Fountain(_token0, _token1);
    }

    /*###############################################################
                            FEES LOGIC
    ###############################################################*/

    function claimFeesFor(address recipient) public nonReentrant returns (uint256 claimed0, uint256 claimed1) {
        return _claimFees(recipient);
    }

    function _claimFees(address recipient) internal returns (uint256 claimed0, uint256 claimed1) {
        claimed0 = claimable0[recipient];
        claimed1 = claimable1[recipient];

        // early exit
        if (claimed0 == 0 && claimed1 == 0) {
            return (0, 0);
        }

        claimable0[recipient] = 0;
        claimable1[recipient] = 0;

        feesDistributor.squirt(recipient, claimed0, claimed1);

        emit Claim(recipient, claimed0, claimed1);
    }

    function _transferAllFeesFrom(address from, address to) internal {
        // if fees are being sent to self (when burning LP), don't transfer fees
        if (to == address(this)) {
            return;
        } else {
            uint256 _fees0 = claimable0[from];
            uint256 _fees1 = claimable1[from];
            claimable0[from] = 0;
            claimable1[from] = 0;
            claimable0[to] += _fees0;
            claimable1[to] += _fees1;
        }
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

    function _update0(uint256 amount) internal {
        SafeTransferLib.safeTransfer(ERC20(token0), address(feesDistributor), amount);
        uint256 _ratio = amount * 1e18 / totalSupply; // 1e18 adjustment is removed during claim
        if (_ratio > 0) {
            index0 += _ratio;
        }
    }

    // Accrue fees on token1
    function _update1(uint256 amount) internal {
        SafeTransferLib.safeTransfer(ERC20(token1), address(feesDistributor), amount);
        uint256 _ratio = amount * 1e18 / totalSupply;
        if (_ratio > 0) {
            index1 += _ratio;
        }
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
        if(!(liquidity > 0)) {
            revert InsuffcientLiquidityMinted();
        }
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
        if(!(amount0 > 0 && amount1 > 0)) {
            revert InsuffcientLiquidityBurned();
        }
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
        bytes calldata data
    ) external override {
        address stargateRouter = factory.stargateRouter();
        if(msg.sender != stargateRouter) {
            revert NotStargate();
        }
        if(keccak256(_srcAddress) != keccak256(sgTrustedBridge[_srcChainId])) {
            revert NotTrusted();
        }
        uint256 syncID = abi.decode(data, (uint256));
        uint32 domain = SGHyperlaneConverter.sgToHyperlane(_srcChainId);
        if (_token == token0) {
            lastBridged0[domain][syncID] = _bridgedAmount;
        } else if (_token == token1) {
            lastBridged1[domain][syncID] = _bridgedAmount;
        }
        emit Bridged(_srcChainId, syncID, _token, _bridgedAmount);
    }

    function handle(uint32 origin, bytes32 sender, bytes calldata payload) external onlyMailbox {
        // check if message is from trusted remote
        if(trustedRemoteLookup[origin] != sender) {
            revert NotTrusted();
        }
        uint256 messageType = abi.decode(payload, (uint256));
        if (messageType == MessageType.BURN_VOUCHERS) {
            // receive both amounts and a single address to determine ordering
            (, address user, uint256 amount0, uint256 amount1) =
                abi.decode(payload, (uint256, address, uint256, uint256));
            _completeVoucherBurns(origin, user, amount0, amount1);
        } else if (messageType == MessageType.SYNC_TO_L1) {
            (, uint256 syncID, address token, uint256 earmarkedDelta, uint256 pairBalance) =
                abi.decode(payload, (uint256, uint256, address, uint256, uint256));
            _syncFromL2(origin, syncID, token, earmarkedDelta, pairBalance);
        }
    }

    function syncL2(uint32 destinationDomain, address pair) external payable {
        bytes memory payload = abi.encode(MessageType.SYNC_TO_L2, token0, reserve0, reserve1);
        bytes32 id = mailbox.dispatch(destinationDomain, TypeCasts.addressToBytes32(pair), payload);
        hyperlaneGasMaster.payGasFor{value: msg.value}(id, destinationDomain);
    }

    function finalizeSyncFromL2(uint32 originDomain, uint256 syncID) external {
        if(!(lastBridged0[originDomain][syncID] > 0 && lastBridged1[originDomain][syncID] > 0)) {
            revert NoStargateSwaps();
        }
        Sync memory sync = syncs[originDomain][syncID];
        (PartialSync memory partialSync0, PartialSync memory partialSync1) = sync.partialSyncA.token == token0
            ? (sync.partialSyncA, sync.partialSyncB)
            : (sync.partialSyncB, sync.partialSyncA);
        _finalizeSyncFromL2(originDomain, syncID, partialSync0, partialSync1);
    }

    function claimBurn(uint32 srcDomain, address user) external {
        BurnClaim memory burnClaim = burnClaims[srcDomain][user];

        uint256 amount0 = burnClaim.amount0;
        uint256 amount1 = burnClaim.amount1;

        delete burnClaims[srcDomain][user];

        marked0[srcDomain] -= amount0;
        marked1[srcDomain] -= amount1;
        fountain.squirt(user, amount0, amount1);

        if (user == address(this)) {
            _update(ERC20(token0).balanceOf(address(this)), ERC20(token1).balanceOf(address(this)), reserve0, reserve1);
        }
    }

    /*###############################################################
                            INTERNAL FUNCTIONS
    ###############################################################*/

    /// @notice Completes a voucher burn initiated on the L2.
    /// @dev Checks if user is able to burn or not should be done on L2 beforehand.
    /// @param srcDomain The domain id of the remote chain.
    /// @param user The user who initiated the burn.
    /// @param amount0 The quantity of local token0 tokens.
    /// @param amount1 The quantity of local token1 tokens.
    function _completeVoucherBurns(uint32 srcDomain, address user, uint256 amount0, uint256 amount1)
        internal
    {
        // if not enough to satisfy, just save the claim
        if (amount0 > marked0[srcDomain] || amount1 > marked1[srcDomain]) {
            // cumulate burns
            BurnClaim memory burnClaim = burnClaims[srcDomain][user];
            burnClaims[srcDomain][user] = BurnClaim(
                burnClaim.amount0 + amount0,
                burnClaim.amount1 + amount1
            );
            emit BurnClaimCreated(srcDomain, user, amount0, amount1);
            return;
        }
        // update earmarked tokens
        marked0[srcDomain] -= amount0;
        marked1[srcDomain] -= amount1;
        fountain.squirt(user, amount0, amount1);
    }

    function _syncFromL2(uint32 origin, uint256 syncID, address token, uint256 earmarkedDelta, uint256 pairBalance)
        internal
    {
        Sync memory sync = syncs[origin][syncID];
        // sync.partialSync1 should always be the first one to be set, regardless
        // if it's token0 or token1 being bridged
        if (sync.partialSyncA.token == address(0)) {
            syncs[origin][syncID].partialSyncA = PartialSync(token, pairBalance, earmarkedDelta);
        } else {
            // can proceed with full sync since we got the two HyperLane messages
            // have to check if SG swaps are completed
            if (lastBridged0[origin][syncID] > 0 && lastBridged1[origin][syncID] > 0) {
                // if incoming message's token is token0, means partialSyncA is token1
                if (token == token0) {
                    _finalizeSyncFromL2(
                        origin, syncID, PartialSync(token, pairBalance, earmarkedDelta), sync.partialSyncA
                    );
                } else {
                    _finalizeSyncFromL2(
                        origin, syncID, sync.partialSyncA, PartialSync(token, pairBalance, earmarkedDelta)
                    );
                }
                // reset
                delete syncs[origin][syncID];
            } else {
                // otherwise means there is at least one SG swap that hasn't completed yet
                // so we need to store the HL data and execute the sync when the SG swap is done
                syncs[origin][syncID].partialSyncB = PartialSync(token, pairBalance, earmarkedDelta);
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
        {
            uint256 fees0 = lastBridged0[srcDomain][syncID] - partialSync0.pairBalance;
            uint256 fees1 = lastBridged1[srcDomain][syncID] - partialSync1.pairBalance;
            _update0(fees0);
            _update1(fees1);
            emit Fees(srcDomain, fees0, fees1);
            // cleanup
            delete lastBridged0[srcDomain][syncID];
            delete lastBridged1[srcDomain][syncID];
        }
        uint256 balance0 = ERC20(partialSync0.token).balanceOf(address(this));
        uint256 balance1 = ERC20(partialSync1.token).balanceOf(address(this));
        _update(balance0, balance1, _reserve0, _reserve1);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _updateFor(msg.sender);
        _updateFor(to);
        _transferAllFeesFrom(msg.sender, to);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _updateFor(from);
        _updateFor(to);
        _transferAllFeesFrom(from, to);
        return super.transferFrom(from, to, amount);
    }

    /*###############################################################
                            VIEW FUNCTIONS
    ###############################################################*/

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }
}
