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
    event Sync(uint256 reserve0, uint256 reserve1);
    event VouchersYeeted(address sender, uint256 amount0, uint256 amount1);
    event VouchersBurnInitiated(address sender, uint256 amount0, uint256 amount1);
    event SyncToL1Initiated(uint256 amount0, uint256 amount1, uint256 fees0, uint256 fees1);
    event SyncedFromL1(uint256 reserve0, uint256 reserve1);

    error InsufficientOutputAmount();
    error InsufficientLiquidity();
    error InvalidTo();
    error InsufficientInputAmount();
    error kInvariant();
    error NoVouchers();
    error MsgValueTooLow();
    error WrongOrigin();
    error NotDove();

    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);
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


interface IFeesAccumulator {
    function take() external returns (uint256 fees0, uint256 fees1);
}

interface IL2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    error IdenticalAddress();
    error ZeroAddress();
    error ZeroAddressOrigin();
    error PairExists();

    struct SGConfig {
        uint16 srcPoolId0;
        uint16 srcPoolId1;
        uint16 dstPoolId0;
        uint16 dstPoolId1;
    }

    function destDomain() external view returns (uint32);
    function destChainId() external view returns (uint16);
    function stargateRouter() external view returns (address);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint256) external view returns (address pair);
    function allPairsLength() external view returns (uint256);
    function pairCodeHash() external pure returns (bytes32);
    function createPair(
        address tokenA,
        address tokenB,
        SGConfig calldata sgConfig,
        address L1TokenA,
        address L1TokenB,
        address L1Target
    ) external returns (address pair);
}


interface IL2Router {
    error Expired();
    error IdenticalAddress();
    error ZeroAddress();
    error InvalidPath();
    error InsufficientOutputAmount();
    error CodeLength();
    error TransferFailed();

    struct route {
        address from;
        address to;
    }

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);
    function getAmountOut(uint256 amountIn, address tokenIn, address tokenOut) external view returns (uint256 amount);
    function getAmountsOut(uint256 amountIn, route[] memory routes) external view returns (uint256[] memory amounts);
    function isPair(address pair) external view returns (bool);
    function swapExactTokensForTokensSimple(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        route[] memory routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}


interface IVoucher {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}


interface IStargateRouter {
    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
    }

    function addLiquidity(uint256 _poolId, uint256 _amountLD, address _to) external;

    function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable;

    function redeemRemote(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLP,
        uint256 _minAmountLD,
        bytes calldata _to,
        lzTxObj memory _lzTxParams
    ) external payable;

    function instantRedeemLocal(uint16 _srcPoolId, uint256 _amountLP, address _to) external returns (uint256);

    function redeemLocal(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLP,
        bytes calldata _to,
        lzTxObj memory _lzTxParams
    ) external payable;

    function sendCredits(uint16 _dstChainId, uint256 _srcPoolId, uint256 _dstPoolId, address payable _refundAddress)
        external
        payable;

    function quoteLayerZeroFee(
        uint16 _dstChainId,
        uint8 _functionType,
        bytes calldata _toAddress,
        bytes calldata _transferAndCallPayload,
        lzTxObj memory _lzTxParams
    ) external view returns (uint256, uint256);
}
