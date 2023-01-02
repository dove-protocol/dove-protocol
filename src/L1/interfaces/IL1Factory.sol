// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface IL1Factory {
    function stargateRouter() external view returns (address);
}
