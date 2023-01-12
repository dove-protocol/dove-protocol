// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/InvariantTest.sol";

import {Dove} from "src/L1/Dove.sol";

contract DoveInvariant is Test, InvariantTest {
    Dove dove;

    function setUp() external {
        dove = new Dove();
        targetContract(address(dove));
    }

    function invariant_idk() external {
    }
}