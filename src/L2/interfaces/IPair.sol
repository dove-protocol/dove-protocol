// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IPair {
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint128 reserve0, uint128 reserve1);
    event VouchersYeeted(address sender, uint256 amount0, uint256 amount1);
    event VouchersBurnInitiated(address sender, uint256 amount0, uint256 amount1);
    event SyncToL1Initiated(uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1);
    event SyncedFromL1(uint128 reserve0, uint128 reserve1);

    error InsufficientOutputAmount();
    error InsufficientLiquidity();
    error InvalidTo();
    error InsufficientInputAmount();
    error kInvariant();
    error NoVouchers();
    error MsgValueTooLow();
    error WrongOrigin();
    error NotDove();
    error Voucher0LimitReached();
    error Voucher1LimitReached();

    function token0() external view returns (address _token0);
    function token1() external view returns (address _token1);
    function getReserves() external view returns (uint128 reserve0, uint128 reserve1, uint256 blockTimestampLast);
    function balance0() external view returns (uint256);
    function balance1() external view returns (uint256);
    function currentCumulativePrices()
        external
        view
        returns (uint256 reserve0Cumulative, uint256 reserve1Cumulative, uint256 blockTimestamp);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function sync() external;
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256 amountOut);
    function yeetVouchers(uint256 amount0, uint256 amount1) external;
    function syncToL1(uint256 sgFee, uint256 hyperlaneFee) external payable;
    function burnVouchers(uint256 amount0, uint256 amount1) external payable;
}
