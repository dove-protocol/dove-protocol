// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {Voucher} from "./Voucher.sol";
import {FeesAccumulator} from "./FeesAccumulator.sol";

import "../hyperlane/HyperlaneClient.sol";
import "../hyperlane/TypeCasts.sol";

import "./interfaces/IStargateRouter.sol";
import "./interfaces/IL2Factory.sol";

import "../Codec.sol";

/// The AMM logic is taken from https://github.com/transmissions11/solidly/blob/master/contracts/BaseV1-core.sol

contract Pair is ReentrancyGuard, HyperlaneClient {
    /*###############################################################
                            STORAGE
    ###############################################################*/
    IL2Factory public factory;

    address public L1Target;

    ///@notice The bridged token0.
    address public token0;
    ///@dev This is NOT the token0 on L1 but the L1 address
    ///@dev of the token0 on L2.
    address public L1Token0;
    Voucher public voucher0;

    ///@notice The bridged token1.
    address public token1;
    address public L1Token1;
    Voucher public voucher1;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public blockTimestampLast;
    uint256 public reserve0CumulativeLast;
    uint256 public reserve1CumulativeLast;

    FeesAccumulator public feesAccumulator;

    uint64 internal immutable decimals0;
    uint64 internal immutable decimals1;

    IL2Factory.SGConfig internal sgConfig;

    ///@notice "reference" reserves on L1
    uint256 internal ref0;
    uint256 internal ref1;
    // amount of vouchers minted since last L1->L2 sync
    uint256 internal voucher0Delta;
    uint256 internal voucher1Delta;

    uint256 internal syncID;
    uint256 internal lastSyncTimestamp;

    uint256 constant FEE = 300;

    /*###############################################################
                            EVENTS
    ###############################################################*/
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint256 reserve0, uint256 reserve1);

    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/
    constructor(
        address _token0,
        address _L1Token0,
        address _token1,
        address _L1Token1,
        IL2Factory.SGConfig memory _sgConfig,
        address _gasMaster,
        address _mailbox,
        address _L1Target
    ) HyperlaneClient(_gasMaster, _mailbox, address(0)) {
        factory = IL2Factory(msg.sender);

        L1Target = _L1Target;

        token0 = _token0;
        L1Token0 = _L1Token0;
        token1 = _token1;
        L1Token1 = _L1Token1;

        sgConfig = _sgConfig;

        ERC20 token0_ = ERC20(_token0);
        ERC20 token1_ = ERC20(_token1);

        decimals0 = uint64(10 ** token0_.decimals());
        decimals1 = uint64(10 ** token1_.decimals());

        /// @dev Assume one AMM per L2.
        voucher0 = new Voucher(
            string.concat("v", token0_.name()),
            string.concat("v", token0_.symbol()),
            token0_.decimals()
        );
        voucher1 = new Voucher(
            string.concat("v", token1_.name()),
            string.concat("v", token1_.symbol()),
            token1_.decimals()
        );
        feesAccumulator = new FeesAccumulator(_token0, _token1);
    }

    /*###############################################################
                            AMM LOGIC
    ###############################################################*/

    // TODO ; use balance0() instrad of reserrve0???
    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    // TODO : rename to reserve0???
    function balance0() public view returns (uint256) {
        return ref0 + ERC20(token0).balanceOf(address(this)) - voucher0Delta;
    }

    function balance1() public view returns (uint256) {
        return ref1 + ERC20(token1).balanceOf(address(this)) - voucher1Delta;
    }

    // Accrue fees on token0
    function _update0(uint256 amount) internal {
        SafeTransferLib.safeTransfer(ERC20(token0), address(feesAccumulator), amount);
    }

    // Accrue fees on token1
    function _update1(uint256 amount) internal {
        SafeTransferLib.safeTransfer(ERC20(token1), address(feesAccumulator), amount);
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 _balance0, uint256 _balance1, uint256 _reserve0, uint256 _reserve1) internal {
        uint256 blockTimestamp = block.timestamp;
        uint256 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            reserve0CumulativeLast += _reserve0 * timeElapsed;
            reserve1CumulativeLast += _reserve1 * timeElapsed;
        }

        reserve0 = _balance0;
        reserve1 = _balance1;
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // produces the cumulative price using counterfactuals to save gas and avoid a call to sync.
    function currentCumulativePrices()
        public
        view
        returns (uint256 reserve0Cumulative, uint256 reserve1Cumulative, uint256 blockTimestamp)
    {
        blockTimestamp = block.timestamp;
        reserve0Cumulative = reserve0CumulativeLast;
        reserve1Cumulative = reserve1CumulativeLast;

        // if time has elapsed since the last update on the pair, mock the accumulated price values
        (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast) = getReserves();
        if (_blockTimestampLast != blockTimestamp) {
            // subtraction overflow is desired
            uint256 timeElapsed = blockTimestamp - _blockTimestampLast;
            reserve0Cumulative += _reserve0 * timeElapsed;
            reserve1Cumulative += _reserve1 * timeElapsed;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external nonReentrant {
        //require(!BaseV1Factory(factory).isPaused());
        require(amount0Out > 0 || amount1Out > 0, "IOA"); // BaseV1: INSUFFICIENT_OUTPUT_AMOUNT
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "IL"); // BaseV1: INSUFFICIENT_LIQUIDITY

        uint256 _balance0;
        uint256 _balance1;
        {
            (address _token0, address _token1) = (token0, token1);
            _balance0 = ERC20(_token0).balanceOf(address(this));
            _balance1 = ERC20(_token1).balanceOf(address(this));
            // scope for _token{0,1}, avoids stack too deep errors
            require(to != _token0 && to != _token1, "IT"); // BaseV1: INVALID_TO
            // optimistically mints vouchers
            if (amount0Out > 0) {
                // delta is what we have to transfer
                // difference between our token balance and what user needs
                (uint256 toSend, uint256 toMint) =
                    _balance0 >= amount0Out ? (amount0Out, 0) : (_balance0, amount0Out - _balance0);
                if (toSend > 0) SafeTransferLib.safeTransfer(ERC20(_token0), to, toSend);
                if (toMint > 0) {
                    voucher0.mint(to, toMint);
                    voucher0Delta += toMint;
                }
            }
            // optimistically mints vouchers
            if (amount1Out > 0) {
                (uint256 toSend, uint256 toMint) =
                    _balance1 >= amount1Out ? (amount1Out, 0) : (_balance1, amount1Out - _balance1);
                if (toSend > 0) SafeTransferLib.safeTransfer(ERC20(_token1), to, toSend);
                if (toMint > 0) {
                    voucher1.mint(to, toMint);
                    voucher1Delta += toMint;
                }
            }
            //if (data.length > 0) IBaseV1Callee(to).hook(msg.sender, amount0Out, amount1Out, data);
            _balance0 = balance0();
            _balance1 = balance1();
        }
        uint256 amount0In = _balance0 > _reserve0 - amount0Out ? _balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = _balance1 > _reserve1 - amount1Out ? _balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "IIA"); // BaseV1: INSUFFICIENT_INPUT_AMOUNT
        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            if (amount0In > 0) _update0(amount0In / FEE); // accrue fees for token0 and move them out of pool
            if (amount1In > 0) _update1(amount1In / FEE); // accrue fees for token1 and move them out of pool
            _balance0 = balance0(); // since we removed tokens, we need to reconfirm balances, can also simply use previous balance - amountIn/ 10000, but doing balanceOf again as safety check
            _balance1 = balance1();
            // The curve, either x3y+y3x for stable pools, or x*y for volatile pools
            require(_k(_balance0, _balance1) >= _k(_reserve0, _reserve1), "K"); // BaseV1: K
        }

        _update(_balance0, _balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    // function skim(address to) external nonReentrant {
    //     (address _token0, address _token1) = (token0, token1);
    //     _safeTransfer(_token0, to, ???);
    //     _safeTransfer(_token1, to, ???);
    // }

    // force reserves to match balances
    function sync() external nonReentrant {
        _update(balance0(), balance1(), reserve0, reserve1);
    }

    function _f(uint256 x0, uint256 y) internal pure returns (uint256) {
        return (x0 * ((((y * y) / 1e18) * y) / 1e18)) / 1e18 + (((((x0 * x0) / 1e18) * x0) / 1e18) * y) / 1e18;
    }

    function _d(uint256 x0, uint256 y) internal pure returns (uint256) {
        return (3 * x0 * ((y * y) / 1e18)) / 1e18 + ((((x0 * x0) / 1e18) * x0) / 1e18);
    }

    function _get_y(uint256 x0, uint256 xy, uint256 y) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 y_prev = y;
            uint256 k = _f(x0, y);
            if (k < xy) {
                uint256 dy = ((xy - k) * 1e18) / _d(x0, y);
                y = y + dy;
            } else {
                uint256 dy = ((k - xy) * 1e18) / _d(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        amountIn -= amountIn / FEE; // remove fee from amount received
        return _getAmountOut(amountIn, tokenIn, _reserve0, _reserve1);
    }

    function _getAmountOut(uint256 amountIn, address tokenIn, uint256 _reserve0, uint256 _reserve1)
        internal
        view
        returns (uint256)
    {
        uint256 xy = _k(_reserve0, _reserve1);
        _reserve0 = (_reserve0 * 1e18) / decimals0;
        _reserve1 = (_reserve1 * 1e18) / decimals1;
        (uint256 reserveA, uint256 reserveB) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
        amountIn = tokenIn == token0 ? (amountIn * 1e18) / decimals0 : (amountIn * 1e18) / decimals1;
        uint256 y = reserveB - _get_y(amountIn + reserveA, xy, reserveB);
        return (y * (tokenIn == token0 ? decimals1 : decimals0)) / 1e18;
    }

    function _k(uint256 x, uint256 y) internal view returns (uint256) {
        uint256 _x = (x * 1e18) / decimals0;
        uint256 _y = (y * 1e18) / decimals1;
        uint256 _a = (_x * _y) / 1e18;
        uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
        return (_a * _b) / 1e18; // x3y+y3x >= k
    }

    /*###############################################################
                            CROSS-CHAIN LOGIC
    ###############################################################*/

    function yeetVouchers(uint256 amount0, uint256 amount1) external nonReentrant {
        voucher0.transferFrom(msg.sender, address(this), amount0);
        voucher1.transferFrom(msg.sender, address(this), amount1);

        SafeTransferLib.safeTransfer(ERC20(token0), msg.sender, amount0);
        SafeTransferLib.safeTransfer(ERC20(token1), msg.sender, amount1);
    }

    function getSyncerPercentage() external view returns (uint64) {
        // reaches 50% over 24h => 0.06 bps per second
        uint256 bps = ((block.timestamp - lastSyncTimestamp) * 6) / 100;
        bps = bps >= 5000 ? 5000 : bps;
        return uint64(bps);
    }

    /// @notice Syncs to the L1.
    /// @dev Dependent on SG.
    function syncToL1(uint256 sgFee, uint256 hyperlaneFee) external payable {
        require(msg.value >= (sgFee + hyperlaneFee) * 2, "SG fee + HL fee");
        ERC20 _token0 = ERC20(token0);
        ERC20 _token1 = ERC20(token1);
        // balance before getting accumulated fees
        uint256 _balance0 = _token0.balanceOf(address(this));
        uint256 _balance1 = _token1.balanceOf(address(this));
        (uint256 fees0, uint256 fees1) = feesAccumulator.take();

        uint32 destDomain = factory.destDomain();
        uint16 destChainId = factory.destChainId();

        IStargateRouter stargateRouter = IStargateRouter(factory.stargateRouter());
        {
            uint256 pairVoucher0Balance = voucher0.balanceOf(address(this));
            // swap token0
            _token0.approve(address(stargateRouter), _balance0 + fees0);
            stargateRouter.swap{value: sgFee}(
                destChainId,
                sgConfig.srcPoolId0,
                sgConfig.dstPoolId0,
                payable(msg.sender),
                _balance0 + fees0,
                _balance0,
                IStargateRouter.lzTxObj(200000, 0, "0x"),
                abi.encodePacked(L1Target),
                "1"
            );
            bytes memory payload = Codec.encodeSyncToL1(
                syncID,
                L1Token0,
                pairVoucher0Balance,
                voucher0Delta - pairVoucher0Balance,
                _balance0,
                msg.sender,
                this.getSyncerPercentage()
            );
            bytes32 id = mailbox.dispatch(destDomain, TypeCasts.addressToBytes32(L1Target), payload);
            hyperlaneGasMaster.payGasFor{value: hyperlaneFee}(id, destDomain);
            reserve0 = ref0 + _balance0 - (voucher0Delta - pairVoucher0Balance);
        }

        {
            uint256 pairVoucher1Balance = voucher1.balanceOf(address(this));
            // swap token1
            _token1.approve(address(stargateRouter), _balance1 + fees1);
            stargateRouter.swap{value: sgFee}(
                destChainId,
                sgConfig.srcPoolId1,
                sgConfig.dstPoolId1,
                payable(msg.sender),
                _balance1 + fees1,
                _balance1,
                IStargateRouter.lzTxObj(200000, 0, "0x"),
                abi.encodePacked(L1Target),
                "1"
            );
            bytes memory payload = Codec.encodeSyncToL1(
                syncID,
                L1Token1,
                pairVoucher1Balance,
                voucher1Delta - pairVoucher1Balance,
                _balance1,
                msg.sender,
                this.getSyncerPercentage()
            );
            bytes32 id = mailbox.dispatch(destDomain, TypeCasts.addressToBytes32(L1Target), payload);
            hyperlaneGasMaster.payGasFor{value: hyperlaneFee}(id, destDomain);
            reserve1 = ref1 + _balance1 - (voucher1Delta - pairVoucher1Balance);
        }

        ref0 = reserve0;
        ref1 = reserve1;
        voucher0Delta = 0;
        voucher1Delta = 0;
        syncID++;
        lastSyncTimestamp = block.timestamp;
    }

    /// @notice Allows user to burn his L2 vouchers to get the L1 tokens.
    /// @param amount0 The amount of voucher0 to burn.
    /// @param amount1 The amount of voucher1 to burn.
    function burnVouchers(uint256 amount0, uint256 amount1) external payable nonReentrant {
        uint32 destDomain = factory.destDomain();
        // tell L1 that vouchers been burned
        require(amount0 > 0 || amount1 > 0, "NO VOUCHERS");
        if (amount0 > 0) voucher0.burn(msg.sender, amount0);
        if (amount1 > 0) voucher1.burn(msg.sender, amount1);
        (amount0, amount1) = _getL1Ordering(amount0, amount1);
        bytes memory payload = Codec.encodeVouchersBurn(msg.sender, amount0, amount1);
        bytes32 id = mailbox.dispatch(destDomain, TypeCasts.addressToBytes32(L1Target), payload);
        hyperlaneGasMaster.payGasFor{value: msg.value}(id, destDomain);
    }

    function handle(uint32 origin, bytes32 sender, bytes calldata payload) external onlyMailbox {
        uint32 destDomain = factory.destDomain();
        require(origin == destDomain, "WRONG ORIGIN");
        require(TypeCasts.addressToBytes32(L1Target) == sender, "NOT DOVE");
        uint256 messageType = abi.decode(payload, (uint256));
        if (messageType == Codec.SYNC_TO_L2) {
            Codec.SyncToL2Payload memory sp = Codec.decodeSyncToL2(payload);
            _syncFromL1(sp);
        }
    }

    function _syncFromL1(Codec.SyncToL2Payload memory sp) internal {
        (reserve0, reserve1) = sp.token0 == L1Token0 ? (sp.reserve0, sp.reserve1) : (sp.reserve1, sp.reserve0);
        ref0 = reserve0;
        ref1 = reserve1;
    }

    function _getL1Ordering(uint256 amount0, uint256 amount1) internal view returns (uint256, uint256) {
        if (L1Token0 < L1Token1) {
            return (amount0, amount1);
        } else {
            return (amount1, amount0);
        }
    }
}
