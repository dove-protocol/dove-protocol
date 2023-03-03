// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { L1ToL2SyncActor } from "./actors/L1ToL2SyncActor.sol";

import { BaseInvariant } from "./BaseInvariant.t.sol";
import { Minter } from "../utils/Minter.sol";

contract L1ToL2SyncInvariant is BaseInvariant {

    L1ToL2SyncActor public actor;

    function setUp() public override {
        super.setUp();

        // deploy actor
        actor = new L1ToL2SyncActor(address(pair01Poly), address(dove01), address(routerL1));

        // selectors for actor
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = bytes4(0x5249f13e);
        selectors[1] = bytes4(0xe2bbb158);
        selectors[2] = bytes4(0x2e1a7d4d);
        FuzzSelector memory fuzzSelector = FuzzSelector({
        addr: address(actor),
        selectors: selectors
        });

        // give actor pool tokens
        Minter.mintDAIL1(dove01.token0(), address(actor), 2 ** 25);
        Minter.mintUSDCL1(dove01.token1(), address(actor), 2 ** 13);

        targetSelector(fuzzSelector);
    }

    function invariant_syncL2() external {
        invariantL1ToL2ReserveSync();
        
    }
}