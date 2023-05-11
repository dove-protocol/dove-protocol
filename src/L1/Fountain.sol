// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract Fountain {
    error OnlyOwner();

    /// @notice owner, this will be the dove pool contract that deploys this contract
    address internal owner;
    /// @notice token addresses
    address internal token0;
    address internal token1;

    /// @notice constructor
    /// @param _token0 token0 address
    /// @param _token1 token1 address
    constructor(address _token0, address _token1) {
        owner = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }

    /// @notice transfer tokens to recipient
    /// @param recipient recipient address
    /// @param amount0 amount of token0 to transfer
    /// @param amount1 amount of token1 to transfer
    /// @dev squirt squirt
    function squirt(address recipient, uint256 amount0, uint256 amount1) external {
        if (msg.sender != owner) revert OnlyOwner();
        if (amount0 > 0) SafeTransferLib.safeTransfer(ERC20(token0), recipient, amount0);
        if (amount1 > 0) SafeTransferLib.safeTransfer(ERC20(token1), recipient, amount1);
    }
}
