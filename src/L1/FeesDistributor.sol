// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract FeesDistributor {

    error OnlyOwner();

    address internal owner;
    address internal token0;
    address internal token1;

    constructor(address _token0, address _token1) {
        owner = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }

    function claimFeesFor(address recipient, uint256 fees0, uint256 fees1) external {
        if(msg.sender != owner) {
            revert OnlyOwner();
        }
        if (fees0 > 0) SafeTransferLib.safeTransfer(ERC20(token0), recipient, fees0);
        if (fees1 > 0) SafeTransferLib.safeTransfer(ERC20(token1), recipient, fees1);
    }
}
