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

    function token0() external view returns (address _token0);
    function token1() external view returns (address _token1);
    function addTrustedRemote(uint32 origin, bytes32 sender) external;
    function addStargateTrustedBridge(uint16 chainId, address remote, address local) external;
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
