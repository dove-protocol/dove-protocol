// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "../../Codec.sol";

interface IDove {
    event Fees(uint256 indexed srcDomain, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Claim(address indexed recipient, uint256 amount0, uint256 amount1);
    event FeesUpdated(address recipient, uint256 amount0, uint256 amount1);
    event FeesTransferred(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
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
    event BurnClaimed(uint256 srcDomain, address indexed user, uint256 amount0, uint256 amount1);
    event BurnClaimCreated(uint256 indexed srcDomain, address indexed user, uint256 amount0, uint256 amount1);

    error LiquidityLocked();
    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error NotStargate();
    error NotTrusted();
    error NoStargateSwaps();

    struct Sync {
        Codec.SyncToL1Payload partialSyncA;
        Codec.SyncToL1Payload partialSyncB;
    }

    struct BurnClaim {
        uint256 amount0;
        uint256 amount1;
    }

    function claimFeesFor(address recipient) external returns (uint256 claimed0, uint256 claimed1);
    function isLiquidityLocked() external view returns (bool);
    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function sync() external;
    function syncL2(uint32 destinationDomain, address pair) external payable;
    function finalizeSyncFromL2(uint32 originDomain, uint256 syncID) external;
    function claimBurn(uint32 srcDomain, address user) external;
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1);
}


interface IFountain {
    function squirt(address recipient, uint256 amount0, uint256 amount1) external;
}


interface IL1Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    error OnlyPauser();
    error OnlyPendingPauser();
    error IdenticalAddress();
    error ZeroAddress();
    error PairAlreadyExists();

    function stargateRouter() external view returns (address);
    function isPair(address pair) external view returns (bool);
    function getPair(address tokenA, address token) external view returns (address);
    function allPairsLength() external view returns (uint256);
    function setPauser(address _pauser) external;
    function acceptPauser() external;
    function setPause(bool _state) external;
    function pairCodeHash() external pure returns (bytes32);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}


interface IL1Router {
    error Expired();
    error IdenticalAddress();
    error ZeroAddress();
    error InsuffcientAmountForQuote();
    error InsufficientLiquidity();
    error BelowMinimumAmount();
    error PairDoesNotExist();
    error InsufficientAmountA();
    error InsufficientAmountB();
    error TransferLiqToPairFailed();
    error CodeLength();
    error TransferFailed();

    struct route {
        address from;
        address to;
        bool stable;
    }

    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1);
    function pairFor(address tokenA, address tokenB) external view returns (address pair);
    function getReserves(address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB);
    function isPair(address pair) external view returns (bool);
    function quoteAddLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired)
        external
        view
        returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    function quoteRemoveLiquidity(address tokenA, address tokenB, uint256 liquidity)
        external
        view
        returns (uint256 amountA, uint256 amountB);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);
}


interface ISGHyperlaneConverter {
    function sgToHyperlane(uint16 sgIdentifier) external pure returns (uint32 domain);
}