// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { L1Actor } from "./actors/L1Actor.sol";

import { BaseInvariant } from "./BaseInvariant.t.sol";
import { Minter } from "../utils/Minter.sol";

contract L1BasicInvariant is BaseInvariant {

    L1Actor public actor;

    function setUp() external {
        _setUp();

        // deploy actor
        actor = new L1Actor();

        // selectors for actor
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(0xe2bbb158);
        selectors[1] = bytes4(0x2e1a7d4d);
        FuzzSelector memory fuzzSelector = FuzzSelector({
        addr: address(actor),
        selectors: selectors
        });

        // give actor pool tokens
        Minter.mintDAIL1(dove.token0(), address(actor), 2 ** 25);
        Minter.mintUSDCL1(dove.token1(), address(actor), 2 ** 13);

        targetSelector(fuzzSelector);
    }

    function invariant_dove() external {
        invariantDoveSolvency();
    }

}
