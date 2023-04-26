// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { L2Actor } from "./actors/L2Actor.sol";

import { BaseInvariant } from "./BaseInvariant.t.sol";
import { Minter } from "../utils/Minter.sol";

contract L2BasicInvariant is BaseInvariant {

    L2Actor public actor;

    function setUp() external {
        _setUp();
        vm.selectFork(L2_FORK_ID);

        // deploy actor
        actor = new L2Actor();

        // selectors for actor
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(0xdf1b3a32);
        selectors[1] = bytes4(0x6220bc9e);
        FuzzSelector memory fuzzSelector = FuzzSelector({
        addr: address(actor),
        selectors: selectors
        });

        // give actor pool tokens
        Minter.mintDAIL2(pair.token0(), address(actor), 2 ** 25);
        Minter.mintUSDCL2(pair.token1(), address(actor), 2 ** 13);

        targetSelector(fuzzSelector);
    }

    function invariant_pair() external {
        invariantPairSolvency();
        invariantPairBalances();
    }

}