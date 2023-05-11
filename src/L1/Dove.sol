// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {SafeTransferLib as STL} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

import {Fountain} from "./Fountain.sol";
import {SGHyperlaneConverter} from "./SGHyperlaneConverter.sol";

import "../hyperlane/TypeCasts.sol";

import "./interfaces/IDove.sol";
import "./interfaces/IStargateReceiver.sol";
import "./interfaces/IL1Factory.sol";
import "../hyperlane/HyperlaneClient.sol";

import "../Codec.sol";

contract Dove is IDove, IStargateReceiver, Owned, HyperlaneClient, ERC20, ReentrancyGuard {
    /// @notice constants
    // minimum liquidity able to be minted through a LP deposit within dove.mint()
    uint256 internal constant MINIMUM_LIQUIDITY = 10 ** 3;
    // Lock period length for LP tokens where no mints or burns can occur
    uint256 internal constant LIQUIDITY_LOCK_PERIOD = 7 days;
    // Unlock period length for LP tokens where any mints/burns can occur
    uint256 internal constant LIQUIDITY_UNLOCK_PERIOD = 1 days;

    IL1Factory public factory;

    /// @notice Dove pool reserve token addresses
    address public token0;
    address public token1;

    /// @notice Dove pool reserves
    uint128 public reserve0;
    uint128 public reserve1;

    /// @notice index is used to accumulate fees denominated in both assets (0 & 1), this is then split out from normal trades to keep the swap "clean"
    // this further allows LP holders to easily claim fees for tokens they have/staked.
    uint256 public index0;
    uint256 public index1;

    /// @notice Fountain contracts
    // used for liquidity providers to claim fees
    Fountain public feesDistributor;
    // used for traders to claim there tokens on L1 that were vouched for on a given L2
    Fountain public fountain;

    /// @notice stuct used to store earmarked token balances for both reserve assets after sync finalization
    struct Marked {
        uint128 marked0;
        uint128 marked1;
    }

    /// @notice Dove mappings (used for storing contextual cross-chain metadata from syncs and constants for cross-chain infra)
    // domain id [hyperlane] => earmarked token balances stored within Marked
    mapping(uint32 => Marked) public marked;
    // struct Sync {
    //    struct PartialSync0,
    //    struct PartialSync1,
    //    struct SyncerMetadata
    // }
    // reference "Codec.sol" for more detail on sub-structs contained in Sync
    // syncs[domain id][syncID] => Sync (struct used to store sync metadata for Sync message sender and both reserve assets)
    mapping(uint32 => mapping(uint16 => Sync)) public syncs;
    // burnClaims[domain id][user address] => BurnClaim (struct used to store burn claims for both reserve assets)
    mapping(uint32 => mapping(address => BurnClaim)) public burnClaims;
    // domain id => hyperlane remote address (reference hyperlane docs for info on remotes)
    mapping(uint32 => bytes32) public trustedRemoteLookup;
    // chain id => trusted stargate bridge pair (remote & local)
    mapping(uint16 => bytes) public sgTrustedBridge;
    // lastBridged[domain][syncID] => amount of tokens last bridged by stargate for each reserve asset
    mapping(uint32 => mapping(uint16 => uint256)) internal lastBridged0;
    mapping(uint32 => mapping(uint16 => uint256)) internal lastBridged1;
    // LP provider address => supplyIndex (position assigned to each LP tracking their current index vs the global position)
    mapping(address => uint256) public supplyIndex0;
    mapping(address => uint256) public supplyIndex1;
    // LP provider address => claimable (tracks the amount of unclaimed, but claimable token fees for token0 & token1)
    mapping(address => uint256) public claimable0;
    mapping(address => uint256) public claimable1;

    /// @notice add a new trusted hyperlane remote
    function addTrustedRemote(uint32 origin, bytes32 sender) external onlyOwner {
        trustedRemoteLookup[origin] = sender;
    }

    /// @notice add a new trusted stargate bridge pair (remote & local)
    function addStargateTrustedBridge(uint16 chainId, address remote, address local) external onlyOwner {
        sgTrustedBridge[chainId] = abi.encodePacked(remote, local);
    }

    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/

    /// @notice timestamp when the first liquidity locking/unlocking epoch starts
    uint256 internal startEpoch;

    /// @notice constructor
    /// @param _token0 address of reserve asset 0
    /// @param _token1 address of reserve asset 1
    /// @param _hyperlaneGasMaster address of the hyperlane gas master contract on L1
    /// @param _mailbox address of the hyperlane mailbox contract on L1
    /// @dev each dove is an ERC20 LP token ERC20("Dove", "DVE", 18)
    /// @dev each dove is a HyperlaneClient
    constructor(address _token0, address _token1, address _hyperlaneGasMaster, address _mailbox)
        ERC20("Dove", "DVE", 18)
        HyperlaneClient(_hyperlaneGasMaster, _mailbox, msg.sender)
    {
        // deployed and configured from L1Factory contract
        factory = IL1Factory(msg.sender);
        token0 = _token0;
        token1 = _token1;
        // each dove has its own respective fountains deployed upon creation
        feesDistributor = new Fountain(_token0, _token1);
        fountain = new Fountain(_token0, _token1);
        startEpoch = block.timestamp;
    }

    /*###############################################################
                            FEES LOGIC
    ###############################################################*/

    /// @notice claim fees for recipient
    /// @param recipient address of recipient
    function claimFeesFor(address recipient)
        public
        override
        nonReentrant
        returns (uint256 claimed0, uint256 claimed1)
    {
        return _claimFees(recipient);
    }

    /// @notice claim fees for recipient
    /// @dev used within claimFeesFor(), mint() and burn()
    function _claimFees(address recipient) internal returns (uint256 claimed0, uint256 claimed1) {
        // get claimable amount for recipient
        claimed0 = claimable0[recipient];
        claimed1 = claimable1[recipient];

        // early exit, zero claimable
        if (claimed0 == 0 && claimed1 == 0) {
            return (0, 0);
        }

        // reset claimable amount for recipient
        claimable0[recipient] = 0;
        claimable1[recipient] = 0;

        // squirt squirt
        feesDistributor.squirt(recipient, claimed0, claimed1);

        emit Claim(recipient, claimed0, claimed1);
    }

    /// @notice transfer all fees from "from" to "to"
    /// @dev used within transfer() and transferFrom()
    function _transferAllFeesFrom(address from, address to) internal {
        // if fees are being sent to self (when burning LP), don't transfer fees
        if (to == address(this)) {
            return;
        } else {
            // store claimable fees for "from"
            uint256 _fees0 = claimable0[from];
            uint256 _fees1 = claimable1[from];
            // reset claimable back to 0 for "from"
            claimable0[from] = 0;
            claimable1[from] = 0;
            // add "from" fees to "to"
            claimable0[to] += _fees0;
            claimable1[to] += _fees1;
            emit FeesTransferred(from, _fees0, _fees1, to);
        }
    }

    /// @notice this function MUST be called on any balance changes, otherwise can be used to infinitely claim fees
    /// Fees are segregated from core funds, so fees can never put liquidity at risk
    /// @dev used within mint(), burn(), transfer(), transferFrom()
    function _updateFor(address recipient) internal {
        uint256 _supplied = balanceOf[recipient]; // get LP balance of `recipient`
        if (_supplied > 0) {
            // get last adjusted index for recipient
            uint256 _supplyIndex0 = supplyIndex0[recipient];
            uint256 _supplyIndex1 = supplyIndex1[recipient];
            // get global index for accumulated fees
            uint256 _index0 = index0;
            uint256 _index1 = index1;
            // update user current position to global position
            supplyIndex0[recipient] = _index0;
            supplyIndex1[recipient] = _index1;
            // calculate difference between last position and current position
            uint256 _delta0 = _index0 - _supplyIndex0;
            uint256 _delta1 = _index1 - _supplyIndex1;
            // if there is a difference, add accrued difference for each supplied token
            if (_delta0 > 0) {
                uint256 _share = _supplied * _delta0 / 1e18;
                claimable0[recipient] += _share;
            }
            if (_delta1 > 0) {
                uint256 _share = _supplied * _delta1 / 1e18;
                claimable1[recipient] += _share;
            }
            emit FeesUpdated(recipient, supplyIndex0[recipient], supplyIndex1[recipient]);
        } else {
            // new users are set to the default global state
            supplyIndex0[recipient] = index0;
            supplyIndex1[recipient] = index1;
        }
    }

    /// @notice send token0 fees to the feesDistributor
    /// @dev used within finalizeSyncFromL2()
    function _update0(uint256 amount) internal {
        STL.safeTransfer(token0, address(feesDistributor), amount);
        uint256 _ratio = amount * 1e18 / totalSupply; // 1e18 adjustment is removed during claim
        if (_ratio > 0) {
            index0 += _ratio;
        }
    }

    /// @notice send token1 fees to the feesDistributor
    /// @dev used within finalizeSyncFromL2()
    function _update1(uint256 amount) internal {
        STL.safeTransfer(token1, address(feesDistributor), amount);
        uint256 _ratio = amount * 1e18 / totalSupply;
        if (_ratio > 0) {
            index1 += _ratio;
        }
    }

    /*###############################################################
                            LIQUIDITY LOGIC
    ###############################################################*/

    /// @notice check if the liquidity lock is active
    function isLiquidityLocked() external view override returns (bool) {
        // compute # of epochs so far
        uint256 epochs = (block.timestamp - startEpoch) / (LIQUIDITY_LOCK_PERIOD + LIQUIDITY_UNLOCK_PERIOD);
        // compute timestamp of current epoch's start
        uint256 t0 = startEpoch + epochs * (LIQUIDITY_LOCK_PERIOD + LIQUIDITY_UNLOCK_PERIOD);
        return block.timestamp > t0 && block.timestamp < t0 + LIQUIDITY_LOCK_PERIOD;
    }

    /// @notice set reserve = balance
    /// @dev used within mint(), burn(), sync(), finalizeSyncFromL2()
    function _update(uint256 balance0, uint256 balance1) internal {
        reserve0 = uint128(balance0);
        reserve1 = uint128(balance1);
        emit Updated(reserve0, reserve1);
    }

    /// @notice mint liquidity tokens
    /// @param to recipient of LP tokens
    function mint(address to) external override nonReentrant returns (uint256 liquidity) {
        // revert if liquidity is locked
        if (this.isLiquidityLocked()) revert LiquidityLocked();
        _claimFees(to);
        // store reserves and balanceOf for both tokens on stack
        (uint128 _reserve0, uint128 _reserve1) = (reserve0, reserve1);
        uint256 _balance0 = ERC20(token0).balanceOf(address(this));
        uint256 _balance1 = ERC20(token1).balanceOf(address(this));
        // calculate difference
        uint256 _amount0 = _balance0 - _reserve0;
        uint256 _amount1 = _balance1 - _reserve1;
        // store totalSupply on stack
        uint256 _totalSupply = totalSupply;
        // if totalSupply is 0, mint MINIMUM_LIQUIDITY
        if (_totalSupply == 0) {
            liquidity = FixedPointMathLib.sqrt(_amount0 * _amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            // calculate liquidity
            uint256 a = _amount0 * _totalSupply / _reserve0;
            uint256 b = _amount1 * _totalSupply / _reserve1;
            liquidity = a < b ? a : b;
        }
        if (!(liquidity > 0)) revert InsufficientLiquidityMinted();
        // update "to" address state and mint "liquidity" LP tokens for "to"
        _updateFor(to);
        _mint(to, liquidity);
        // update reserves
        _update(_balance0, _balance1);
        emit Mint(msg.sender, _amount0, _amount1);
    }

    /// @notice burn liquidity tokens
    /// @param to recipient of underlying tokens
    function burn(address to) external override nonReentrant returns (uint256 amount0, uint256 amount1) {
        // revert if liquidity is locked
        if (this.isLiquidityLocked()) revert LiquidityLocked();
        _claimFees(to);
        // store reserves and balanceOf for both tokens on stack
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        (address _token0, address _token1) = (token0, token1);
        uint256 _balance0 = STL.balanceOf(_token0, address(this));
        uint256 _balance1 = STL.balanceOf(_token1, address(this));
        // calculate liquidity
        uint256 _liquidity = balanceOf[address(this)];
        // store totalSupply on stack
        uint256 _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        // calculate amounts to send
        amount0 = _liquidity * _balance0 / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = _liquidity * _balance1 / _totalSupply; // using balances ensures pro-rata distribution
        // revert if liquidity is insufficient
        if (!(amount0 > 0 && amount1 > 0)) revert InsufficientLiquidityBurned();
        // update "to" address state and burn "liquidity" LP tokens from "to"
        _updateFor(to);
        _burn(address(this), _liquidity);
        // send "amount" tokens to "to"
        STL.safeTransfer(_token0, to, amount0);
        STL.safeTransfer(_token1, to, amount1);
        // calculate reserve updates
        _balance0 = STL.balanceOf(_token0, address(this));
        _balance1 = STL.balanceOf(_token1, address(this));
        // update reserves
        _update(_balance0, _balance1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    /// @notice sync reserves with balanceOf for both reserve tokens
    function sync() external override nonReentrant {
        _update(ERC20(token0).balanceOf(address(this)), ERC20(token1).balanceOf(address(this)));
    }

    /*###############################################################
                            SYNCING LOGIC
    ###############################################################*/

    /// @notice receiving function for cross chain stargate token transfer
    /// @param _srcChainId source chain id
    /// @param _srcAddress source address
    //  @param _nonce nonce
    /// @param _token token address
    /// @param _bridgedAmount amount of tokens bridged
    /// @param _payload payload containing metadata about the source of the transfer
    function sgReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint256,
        address _token,
        uint256 _bridgedAmount,
        bytes calldata _payload
    ) external override {
        // store stargate router address on stack
        address stargateRouter = factory.stargateRouter();
        // revert if sender is not the expected router
        if (msg.sender != stargateRouter) revert NotStargate();
        // revert if the router has not been added as trusted
        if (keccak256(_srcAddress) != keccak256(sgTrustedBridge[_srcChainId])) revert NotTrusted();
        // infer hyperlane domain from chain id
        uint32 domain = SGHyperlaneConverter.sgToHyperlane(_srcChainId);
        // store sync id on stack
        uint16 syncID = abi.decode(_payload, (uint16));
        // caclulate token ordering, then add bridge amount to update lastBridged for both tokens
        if (_token == token0) {
            lastBridged0[domain][syncID] += _bridgedAmount;
        } else if (_token == token1) {
            lastBridged1[domain][syncID] += _bridgedAmount;
        }
        emit Bridged(_srcChainId, syncID, _token, _bridgedAmount);
    }

    /// @notice receiving function for Hyperlane Clients
    /// @param origin origin domain
    /// @param sender sender of cross-chain message
    /// @param payload message payload
    /// @dev only callable by hyperlane mailbox
    function handle(uint32 origin, bytes32 sender, bytes calldata payload) external onlyMailbox {
        // check if message is from trusted remote, revert if not
        if (trustedRemoteLookup[origin] != sender) revert NotTrusted();
        // decode message type
        uint256 messageType = abi.decode(payload, (uint256));
        // if messageType is Sync or burn, decode the respective payload using Codec's designated function
        if (Codec.getType(payload) == Codec.SYNC_TO_L1) {
            (
                uint16 syncID,
                Codec.SyncerMetadata memory sm,
                Codec.PartialSync memory pSyncA,
                Codec.PartialSync memory pSyncB
            ) = Codec.decodeSyncToL1(payload); // reference Codec
            _syncFromL2(origin, syncID, Sync(pSyncA, pSyncB, sm));
        } else if (messageType == Codec.BURN_VOUCHERS) {
            // reference Codec
            Codec.VouchersBurnPayload memory vbp = Codec.decodeVouchersBurn(payload);
            _completeVoucherBurns(origin, vbp);
        }
    }

    /// @notice sync L1 data to L2 pair at destinationDomain
    /// @param destinationDomain destination hyperlane domain id
    /// @param pair pair address
    function syncL2(uint32 destinationDomain, address pair) external payable override {
        // encode sync data
        bytes memory payload = Codec.encodeSyncToL2(token0, reserve0, reserve1);
        // dispatch sync transaction to mailbox
        bytes32 id = mailbox.dispatch(destinationDomain, TypeCasts.addressToBytes32(pair), payload);
        hyperlaneGasMaster.payForGas{value: msg.value}(id, destinationDomain, 100000, address(msg.sender));
    }

    /// @notice finalize a sync from L2 that did not finalize automatically due to ordering of cross-chain transactions
    /// @param originDomain origin hyperlane domain
    /// @param syncID sync id of sync to finalize
    function finalizeSyncFromL2(uint32 originDomain, uint16 syncID) external override {
        // revert if no stargate swaps have bridged funds
        if (!(lastBridged0[originDomain][syncID] > 0 && lastBridged1[originDomain][syncID] > 0)) {
            revert NoStargateSwaps();
        }
        // load Sync
        Sync memory sync = syncs[originDomain][syncID];
        // NOTE: this is a PVP enabled function meaning whoever finalizes sync here on L1 that is pending gets the reward
        // even if another address paid the funds on the origin L2 to initiate the sync
        sync.sm.syncer = msg.sender;
        _finalizeSyncFromL2(originDomain, syncID, sync);
    }

    /// @notice claim vouchers for "user" originating from "srcDomain"
    /// @param srcDomain source hyperlane domain
    /// @param user user address
    function claimBurn(uint32 srcDomain, address user) external override {
        // load burn claim balances for both assets into memory
        BurnClaim memory burnClaim = burnClaims[srcDomain][user];
        // store balances on stack
        uint128 amount0 = burnClaim.amount0;
        uint128 amount1 = burnClaim.amount1;
        // remove burnClaim struct
        delete burnClaims[srcDomain][user];
        // update earmarked tokens
        marked[srcDomain].marked0 -= amount0;
        marked[srcDomain].marked1 -= amount1;
        // squirt squirt
        fountain.squirt(user, amount0, amount1);
    }

    /*###############################################################
                            INTERNAL FUNCTIONS
    ###############################################################*/

    /// @notice complete voucher burns, accumulate available claims on L1 or squirt if enough funds are available
    /// @param srcDomain source hyperlane domain
    /// @param vbp VouchersBurnPayload
    /// @dev used by the hyperlane client handle() function, when messageType is BURN_VOUCHERS
    function _completeVoucherBurns(uint32 srcDomain, Codec.VouchersBurnPayload memory vbp) internal {
        // if not enough to satisfy, just save the claim
        if (vbp.amount0 > marked[srcDomain].marked0 || vbp.amount1 > marked[srcDomain].marked1) {
            // accumulate burns
            BurnClaim memory burnClaim = burnClaims[srcDomain][vbp.user];
            burnClaims[srcDomain][vbp.user] =
                BurnClaim(burnClaim.amount0 + vbp.amount0, burnClaim.amount1 + vbp.amount1);
            emit BurnClaimCreated(srcDomain, vbp.user, vbp.amount0, vbp.amount1);
        } else {
            // update earmarked tokens
            marked[srcDomain].marked0 -= vbp.amount0;
            marked[srcDomain].marked1 -= vbp.amount1;
            fountain.squirt(vbp.user, vbp.amount0, vbp.amount1);
            emit BurnClaimed(srcDomain, vbp.user, vbp.amount0, vbp.amount1);
        }
    }

    /// @notice handle sync from L2
    /// @param origin origin hyperlane domain
    /// @param syncID sync id
    /// @param sync Sync data
    /// @dev used by the hyperlane client handle() function, when messageType is SYNC_TO_L1
    function _syncFromL2(uint32 origin, uint16 syncID, Sync memory sync) internal {
        // check if stargate swaps have succeeded and as result mutated values in lastBridged0 & lastBridged1
        if (lastBridged0[origin][syncID] > 0 && lastBridged1[origin][syncID] > 0) {
            // if sync finalization succeeds atomically, clear storage
            if (!_finalizeSyncFromL2(origin, syncID, sync)) {
                delete syncs[origin][syncID];
            } else {
                // sync finalization has failed atomically, means there were tokens sent from same L2
                // but NOT from the Pair!
                syncs[origin][syncID] = sync; // record sync for pending finailztion
                emit SyncPending(origin, syncID);
            }
        } else {
            // otherwise there is at least one SG swap that hasn't completed yet
            // so we need to store the HL data and execute the pending sync when the SG swap is done
            syncs[origin][syncID] = sync; // record sync for pending finailztion
            emit SyncPending(origin, syncID);
        }
    }

    /// @notice Finalize sync, Syncing implies bridging the tokens from the L2 back to the L1.
    ///         These tokens are simply added back to the reserves once finalized
    /// @param srcDomain source hyperlane domain
    /// @param syncID sync id
    /// @param sync Sync data
    /// @dev Used by internal function _syncFromL2() executed by hyperlane mailbox on its first attempt
    /// @dev if the atomic cross-chain call to this function made within _syncFromL2() fails, then
    ///      external func finalizeSyncFromL2() can be called by anyone seeking to collect the reward
    ///      for finalizing the sync.
    function _finalizeSyncFromL2(uint32 srcDomain, uint16 syncID, Sync memory sync) internal returns (bool hasFailed) {
        // load tokens and reserves
        (address _token0, address _token1) = (token0, token1);
        (uint128 _reserve0, uint128 _reserve1) = (reserve0, reserve1);
        // re-arrange in correct order the sync's partial syncs
        if (sync.pSyncA.token == token1) {
            (sync.pSyncA, sync.pSyncB) = (sync.pSyncB, sync.pSyncA);
        }
        {
            // store last bridged amounts
            uint256 LB0 = lastBridged0[srcDomain][syncID];
            uint256 LB1 = lastBridged1[srcDomain][syncID];
            // check if pair balance from hyperlane message is greater than last bridged amount from stargate
            // In the case of a correct sync, we would never enter in the block
            // below and would proceed normally.
            if (sync.pSyncA.pairBalance > LB0 || sync.pSyncB.pairBalance > LB1) {
                // early exit
                return true;
            }
            // compute fees
            uint256 fees0 = LB0 - sync.pSyncA.pairBalance;
            uint256 fees1 = LB1 - sync.pSyncB.pairBalance;
            // send over sync reward to the syncer
            STL.safeTransfer(_token0, sync.sm.syncer, fees0 * sync.sm.syncerPercentage / 10000);
            STL.safeTransfer(_token1, sync.sm.syncer, fees1 * sync.sm.syncerPercentage / 10000);
            // update fees with sync reward deducted
            fees0 -= fees0 * sync.sm.syncerPercentage / 10000;
            fees1 -= fees1 * sync.sm.syncerPercentage / 10000;
            // update reserves
            _update0(fees0);
            _update1(fees1);
            emit Fees(srcDomain, fees0, fees1);
            // cleanup
            delete lastBridged0[srcDomain][syncID];
            delete lastBridged1[srcDomain][syncID];
        }
        {
            // update reserves
            reserve0 = _reserve0 + sync.pSyncA.pairBalance - sync.pSyncA.earmarkedAmount;
            reserve1 = _reserve1 + sync.pSyncB.pairBalance - sync.pSyncB.earmarkedAmount;
            // update earmarked tokens
            marked[srcDomain].marked0 += sync.pSyncA.earmarkedAmount;
            marked[srcDomain].marked1 += sync.pSyncB.earmarkedAmount;
            // put earmarked tokens on the side
            STL.safeTransfer(sync.pSyncA.token, address(fountain), sync.pSyncA.earmarkedAmount);
            STL.safeTransfer(sync.pSyncB.token, address(fountain), sync.pSyncB.earmarkedAmount);
        }
        emit SyncFinalized(
            srcDomain,
            syncID,
            sync.pSyncA.pairBalance,
            sync.pSyncB.pairBalance,
            sync.pSyncA.earmarkedAmount,
            sync.pSyncB.earmarkedAmount
        );
        // load token balances of dove
        uint256 balance0 = ERC20(sync.pSyncA.token).balanceOf(address(this));
        uint256 balance1 = ERC20(sync.pSyncB.token).balanceOf(address(this));
        // update reserves
        _update(balance0, balance1);
    }

    /*###############################################################
                            ERC20 FUNCTIONS
    ###############################################################*/

    /// @notice transfer "amount" LP tokens to "to" address
    /// @param to address to transfer LP tokens to
    /// @param amount amount of LP tokens to transfer
    function transfer(address to, uint256 amount) public override returns (bool) {
        _updateFor(msg.sender);
        _updateFor(to);
        _transferAllFeesFrom(msg.sender, to);
        return super.transfer(to, amount);
    }

    /// @notice transfer "amount" LP tokens from "from" address to "to" address
    /// @param from address to transfer LP tokens from
    /// @param to address to transfer LP tokens to
    /// @param amount amount of LP tokens to transfer
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _updateFor(from);
        _updateFor(to);
        _transferAllFeesFrom(from, to);
        return super.transferFrom(from, to, amount);
    }

    /*###############################################################
                            VIEW FUNCTIONS
    ###############################################################*/

    /// @notice get the current reserves of the dove
    function getReserves() external view override returns (uint128, uint128) {
        return (reserve0, reserve1);
    }
}
