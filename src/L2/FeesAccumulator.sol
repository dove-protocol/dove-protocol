// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract FeesAccumulator {
    /// @notice owner, owned by Pair contract
    address owner;
    /// @notice tokens in Pair
    address token0;
    address token1;

    /// @notice constructor
    /// @param _token0 token0 address
    /// @param _token1 token1 address
    constructor(address _token0, address _token1) {
        // set storage
        owner = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }

    /// @notice take fees, only called by Pair that owns this contract
    function take() public returns (uint256 fees0, uint256 fees1) {
        require(msg.sender == owner);
        ERC20 _token0 = ERC20(token0);
        ERC20 _token1 = ERC20(token1);
        fees0 = _token0.balanceOf(address(this));
        fees1 = _token1.balanceOf(address(this));
        SafeTransferLib.safeTransfer(_token0, owner, fees0);
        SafeTransferLib.safeTransfer(_token1, owner, fees1);
    }
}
