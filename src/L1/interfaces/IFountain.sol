// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IFountain {
    function squirt(address recipient, uint256 amount0, uint256 amount1) external;
}
