// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";

import "../hyperlane/HyperlaneClient.sol";
import "../hyperlane/TypeCasts.sol";

import "./interfaces/IStargateRouter.sol";

import "../MessageType.sol";

import {Voucher} from "./Voucher.sol";

/// The AMM logic is taken from https://github.com/transmissions11/solidly/blob/master/contracts/BaseV1-core.sol

contract AMM is ReentrancyGuard, HyperlaneClient {
    /*###############################################################
                            STORAGE
    ###############################################################*/
    IStargateRouter public stargateRouter;
    address public L1Target;

    ///@notice The bridged token0.
    ERC20 public token0;
    address public L1Token0;
    Voucher public voucher0;

    ///@notice The bridged token1.
    ERC20 public token1;
    address public L1Token1;
    Voucher public voucher1;

    uint256 public reserve0; // initially should be set with the L1 data
    uint256 public reserve1; // ...
    uint256 public blockTimestampLast;
    uint256 public reserve0CumulativeLast;
    uint256 public reserve1CumulativeLast;
    /// @notice total accumumated fees (LPs+protocol).
    uint256 public fees0;
    uint256 public fees1;
    // index0 and index1 are used to accumulate fees, this is split out from normal trades to keep the swap "clean"
    // this further allows LP holders to easily claim fees for tokens they have/staked
    uint256 public index0;
    uint256 public index1;

    uint8 internal immutable decimals0;
    uint8 internal immutable decimals1;
    uint32 internal immutable destDomain;
    uint16 internal immutable destChainId;
    uint256 internal balance0;
    uint256 internal balance1;

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
        address _gasMaster,
        address _mailbox,
        address _stargateRouter,
        address _L1Target,
        uint16 _destChainId,
        uint32 _destDomain
    ) HyperlaneClient(_gasMaster, _mailbox, address(0)) {
        destChainId = _destChainId;
        destDomain = _destDomain;
        stargateRouter = IStargateRouter(_stargateRouter);
        L1Target = _L1Target;

        token0 = ERC20(_token0);
        L1Token0 = _L1Token0;
        token1 = ERC20(_token1);
        L1Token1 = _L1Token1;

        decimals0 = 10 ** ERC20(_token0).decimals();
        decimals1 = 10 ** ERC20(_token1).decimals();

        /// @dev Assume one AMM per L2.
        voucher0 =
            new Voucher(string.concat("v", token0.name()), string.concat("v", token0.symbol()), token0.decimals());
        voucher1 =
            new Voucher(string.concat("v", token1.name()), string.concat("v", token1.symbol()), token1.decimals());
    }

    /*###############################################################
                            AMM LOGIC
    ###############################################################*/

    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function balance0() public view returns (uint256) {
        return balance0 + ERC20(token0).balanceOf(address(this)) - voucher0.totalSupply();
    }

    function balance1() public view returns (uint256) {
        return balance1 + ERC20(token1).balanceOf(address(this)) - voucher1.totalSupply();
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1, uint256 _reserve0, uint256 _reserve1) internal {
        uint256 blockTimestamp = block.timestamp;
        uint256 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            reserve0CumulativeLast += _reserve0 * timeElapsed;
            reserve1CumulativeLast += _reserve1 * timeElapsed;
        }

        reserve0 = balance0;
        reserve1 = balance1;
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

    /// @notice Swaps token 0/1 for token 1/0.
    /// @param amount0In The amount of token 0 to swap.
    /// @param amount1In The amount of token 1 to swap.
    /// @return amountOut The amount of the token we swap out.
    function swap(uint256 amount0In, uint256 amount1In) external nonReentrant returns (uint256 amountOut) {
        require(amount0In > 0 || amount1In > 0, "Amounts are 0");
        (ERC20 tokenIn, Voucher voucherOut, uint256 amountIn, uint256 reserveIn, uint256 reserveOut) = amount0In > 0
            ? (token0, voucher1, amount0In, reserve0, reserve1)
            : (token1, voucher0, amount1In, reserve1, reserve0);
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        uint256 fees = amountIn / 100; // 1%
        amountIn -= fees;
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);

        // update reserves
        if (amount0In > 0) {
            fees0 += fees;
            balance0 += amountIn;
            reserve0 += amount0In;
            reserve1 -= amountOut;
        } else {
            fees1 += fees;
            reserve0 -= amountOut;
            reserve1 += amount1In;
            balance1 += amountIn;
        }
        voucherOut.mint(msg.sender, amountOut);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external lock {
        //require(!BaseV1Factory(factory).isPaused());
        require(amount0Out > 0 || amount1Out > 0, "IOA"); // BaseV1: INSUFFICIENT_OUTPUT_AMOUNT
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "IL"); // BaseV1: INSUFFICIENT_LIQUIDITY

        uint256 _balance0;
        uint256 _balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            (address _token0, address _token1) = (token0, token1);
            require(to != _token0 && to != _token1, "IT"); // BaseV1: INVALID_TO
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            if (data.length > 0) IBaseV1Callee(to).hook(msg.sender, amount0Out, amount1Out, data); // callback, used for flash loans
            _balance0 = balance0();
            _balance1 = balance1();
        }
        uint256 amount0In = _balance0 > _reserve0 - amount0Out ? _balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = _balance1 > _reserve1 - amount1Out ? _balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "IIA"); // BaseV1: INSUFFICIENT_INPUT_AMOUNT
        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            (address _token0, address _token1) = (token0, token1);
            if (amount0In > 0) _update0(amount0In / 10000); // accrue fees for token0 and move them out of pool
            if (amount1In > 0) _update1(amount1In / 10000); // accrue fees for token1 and move them out of pool
            _balance0 = balance0(); // since we removed tokens, we need to reconfirm balances, can also simply use previous balance - amountIn/ 10000, but doing balanceOf again as safety check
            _balance1 = balance1();
            // The curve, either x3y+y3x for stable pools, or x*y for volatile pools
            require(_k(_balance0, _balance1) >= _k(_reserve0, _reserve1), "K"); // BaseV1: K
        }

        _update(_balance0, _balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // force balances to match reserves
    function skim(address to) external lock {
        (address _token0, address _token1) = (token0, token1);
        _safeTransfer(_token0, to, ???);
        _safeTransfer(_token1, to, ???);
    }

    // force reserves to match balances
    function sync() external lock {
        _update(
            balance0(),
            balance1(),
            reserve0,
            reserve1
        );
    }

    function _f(uint256 x0, uint256 y) internal pure returns (uint256) {
        return x0 * (y * y / 1e18 * y / 1e18) / 1e18 + (x0 * x0 / 1e18 * x0 / 1e18) * y / 1e18;
    }

    function _d(uint256 x0, uint256 y) internal pure returns (uint256) {
        return 3 * x0 * (y * y / 1e18) / 1e18 + (x0 * x0 / 1e18 * x0 / 1e18);
    }

    function _get_y(uint256 x0, uint256 xy, uint256 y) internal pure returns (uint256) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 y_prev = y;
            uint256 k = _f(x0, y);
            if (k < xy) {
                uint256 dy = (xy - k) * 1e18 / _d(x0, y);
                y = y + dy;
            } else {
                uint256 dy = (k - xy) * 1e18 / _d(x0, y);
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
        amountIn -= amountIn / 10000; // remove fee from amount received
        return _getAmountOut(amountIn, tokenIn, _reserve0, _reserve1);
    }

    function _getAmountOut(uint256 amountIn, address tokenIn, uint256 _reserve0, uint256 _reserve1)
        internal
        view
        returns (uint256)
    {
        if (stable) {
            uint256 xy = _k(_reserve0, _reserve1);
            _reserve0 = _reserve0 * 1e18 / decimals0;
            _reserve1 = _reserve1 * 1e18 / decimals1;
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
            amountIn = tokenIn == token0 ? amountIn * 1e18 / decimals0 : amountIn * 1e18 / decimals1;
            uint256 y = reserveB - _get_y(amountIn + reserveA, xy, reserveB);
            return y * (tokenIn == token0 ? decimals1 : decimals0) / 1e18;
        } else {
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
            return amountIn * reserveB / (reserveA + amountIn);
        }
    }

    function _k(uint256 x, uint256 y) internal view returns (uint256) {
        if (stable) {
            uint256 _x = x * 1e18 / decimals0;
            uint256 _y = y * 1e18 / decimals1;
            uint256 _a = (_x * _y) / 1e18;
            uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
            return _a * _b / 1e18; // x3y+y3x >= k
        } else {
            return x * y; // xy >= k
        }
    }

    /// @notice Syncs to the L1.
    /// @dev Dependent on SG.
    /// @param srcPoolId0 The id of the src pool for token0.
    /// @param dstPoolId0 The id of the dst pool for token0.
    /// @param srcPoolId1 The id of the src pool for token1.
    /// @param dstPoolId1 The id of the dst pool for token1.
    function syncToL1(uint256 srcPoolId0, uint256 dstPoolId0, uint256 srcPoolId1, uint256 dstPoolId1)
        external
        payable
    {
        // swap token0
        uint32 localDomain = mailbox.localDomain();
        bytes memory payload = abi.encode(voucher0.totalSupply(), balance0, localDomain);
        token0.approve(address(stargateRouter), balance0 + fees0);
        stargateRouter.swap{value: msg.value / 2}(
            destChainId,
            srcPoolId0,
            dstPoolId0,
            payable(msg.sender),
            balance0 + fees0,
            0,
            IStargateRouter.lzTxObj(10 ** 6, 0, "0x"),
            abi.encodePacked(L1Target),
            payload
        );
        fees0 = 0;
        balance0 = 0;
        // swap token1
        payload = abi.encode(voucher1.totalSupply(), balance1, localDomain);
        token1.approve(address(stargateRouter), balance1 + fees1);
        stargateRouter.swap{value: msg.value / 2}(
            destChainId,
            srcPoolId1,
            dstPoolId1,
            payable(msg.sender),
            balance1 + fees1,
            0,
            IStargateRouter.lzTxObj(10 ** 6, 0, "0x"),
            abi.encodePacked(L1Target),
            payload
        );
        fees1 = 0;
        balance1 = 0;
    }

    /// @notice Allows user to burn his L2 vouchers to get the L1 tokens.
    /// @param amount0 The amount of voucher0 to burn.
    /// @param amount1 The amount of voucher1 to burn.
    function burnVouchers(uint256 amount0, uint256 amount1) external payable nonReentrant {
        uint256 fee = amount0 > 0 && amount1 > 0 ? msg.value / 2 : msg.value;
        // tell L1 that vouchers been burned
        if (amount0 > 0) {
            voucher0.burn(msg.sender, amount0);
            bytes memory payload = abi.encode(MessageType.BURN_VOUCHER, L1Token0, msg.sender, amount0);
            bytes32 id = mailbox.dispatch(destDomain, TypeCasts.addressToBytes32(L1Target), payload);
            hyperlaneGasMaster.payGasFor{value: fee}(id, destDomain);
        }
        if (amount1 > 0) {
            voucher1.burn(msg.sender, amount1);
            bytes memory payload = abi.encode(MessageType.BURN_VOUCHER, L1Token1, msg.sender, amount1);
            bytes32 id = mailbox.dispatch(destDomain, TypeCasts.addressToBytes32(L1Target), payload);
            hyperlaneGasMaster.payGasFor{value: fee}(id, destDomain);
        }
    }

    function handle(uint32 origin, bytes32 sender, bytes calldata payload) external onlyInbox {
        require(origin == destDomain, "WRONG ORIGIN");
        require(TypeCasts.addressToBytes32(L1Target) == sender, "NOT DOVE");
        (reserve0, reserve1) = abi.decode(payload, (uint256, uint256));
        balance0 = reserve0;
        balance1 = reserve1;
    }
}
