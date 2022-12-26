// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract FeesDistributor {
    address owner;
    address token0;
    address token1;

    constructor(address _token0, address _token1) {
        owner = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }

    function claimFeesFor(address recipient, uint256 amount0, uint256 amount1) external {
        require(msg.sender == owner);
        if (amount0 > 0) SafeTransferLib.safeTransfer(_token0, recipient, fees0);
        if (amount1 > 0) SafeTransferLib.safeTransfer(_token1, recipient, fees1);
    }
}
