// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { L2Actor } from "./actors/L2Actor.sol";

import { BaseInvariant } from "./BaseInvariant.t.sol";
import { Minter } from "../utils/Minter.sol";

contract L2BasicInvariant is BaseInvariant {

    L2Actor public actor;

    function setUp() public override {
        super.setUp();

        // deploy actor
        actor = new L2Actor(address(pair01Poly), address(routerL2));

        // selectors for actor
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = bytes4(0xdf1b3a32);
        selectors[1] = bytes4(0x6220bc9e);
        FuzzSelector memory fuzzSelector = FuzzSelector({
        addr: address(actor),
        selectors: selectors
        });

        // give actor pool tokens
        Minter.mintDAIL1(pair01Poly.token0(), address(actor), 2 ** 25);
        Minter.mintUSDCL1(pair01Poly.token1(), address(actor), 2 ** 13);

        //targetContract(address(actor));
        targetSelector(fuzzSelector);
    }

    function invariant_pair() external {
        invariantPair01PolySolvency();
        invariantPair01PolyBalances();
    }

}