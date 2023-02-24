// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IFeesAccumulator {
    function take() external returns (uint256 fees0, uint256 fees1);
}
