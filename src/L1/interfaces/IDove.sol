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
    event Updated(uint128 reserve0, uint128 reserve1);
    event Bridged(uint256 indexed srcChainId, uint16 syncID, address token, uint256 amount);
    event SyncPending(uint256 indexed srcDomain, uint16 syncID);
    event SyncFinalized(
        uint256 indexed srcDomain,
        uint16 syncID,
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
        Codec.PartialSync pSyncA;
        Codec.PartialSync pSyncB;
        Codec.SyncerMetadata sm;
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
    function finalizeSyncFromL2(uint32 originDomain, uint16 syncID) external;
    function claimBurn(uint32 srcDomain, address user) external;
    function getReserves() external view returns (uint128 reserve0, uint128 reserve1);
}
