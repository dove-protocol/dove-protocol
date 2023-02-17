// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "../../Codec.sol";

interface IDove {
    event Fees(uint256 indexed srcDomain, uint256 amount0, uint256 amount1);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Claim(address indexed recipient, uint256 amount0, uint256 amount1);
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

    function transferFrom(address src, address dst, uint256 amount) external returns (bool);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function mint(address to) external returns (uint256 liquidity);
    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1);
}
