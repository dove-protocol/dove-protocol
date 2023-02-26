// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { L1ActorDoveRouter } from "./actors/L1ActorDoveRouter.sol";

import { BaseInvariant } from "./BaseInvariant.t.sol";
import { Minter } from "../utils/Minter.sol";

contract L1BasicInvariants is BaseInvariant {
    function setUp() public override {
        super.setUp();
        //_excludeAllContracts();

        // deploy actor
        L1ActorDoveRouter actor = new L1ActorDoveRouter(dove01, routerL1);
        // give actor pool tokens
        Minter.mintDAIL1(dove01.token0(), address(actor), 2 ** 60);
        Minter.mintUSDCL1(dove01.token1(), address(actor), 2 ** 36);
        // caller
        address caller = address(0xbeef);
        vm.deal(address(actor), type(uint128).max);

        targetContract(address(actor));
        targetSender(caller);
    }

    function invariant_dove() external {
        invariantDove01Solvency();
    }





}
