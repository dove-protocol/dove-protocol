pragma solidity ^0.8.15;

import {StdInvariant} from "lib/utils/StdInvariant.sol";
import {TestBaseAssertions} from "../TestBaseAssertions.sol";
import {Minter} from "../utils/Minter.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {L1ActorDoveRouter} from "./actors/L1ActorDoveRouter.sol";

contract BaseInvariant is StdInvariant, TestBaseAssertions {

    // --------------------------------------------------------------------------------------------------------
    // Dove Invariants
    // --------------------------------------------------------------------------------------------------------

    /// balance of the token inside dove01 must equal reserves
    function invariantDove01Solvency() external {
        assertEq(
            ERC20(dove01.token0()).balanceOf(address(dove01)),
            dove01.reserve0()
        );
        assertEq(
            ERC20(dove01.token1()).balanceOf(address(dove01)),
            dove01.reserve1()
        );
    } 

    // --------------------------------------------------------------------------------------------------------
    // Pair Invariants
    // --------------------------------------------------------------------------------------------------------

    function invariantPair01PolySolvency() external {
        assertEq(
            ERC20(pair01Poly.token0()).balanceOf(address(pair01Poly)),
            pair01Poly.reserve0()
        );
        assertEq(
            ERC20(pair01Poly.token1()).balanceOf(address(pair01Poly)),
            pair01Poly.reserve1()
        );
    }

    function invariantPair01PolyBalances() external {
        assertLe(
            pair01Poly.balance0(),
            pair01Poly.reserve0()
        );
        assertLe(
            pair01Poly.balance1(),
            pair01Poly.reserve1()
        );
    }

    // --------------------------------------------------------------------------------------------------------
    // Fountain Invariants
    // --------------------------------------------------------------------------------------------------------

    // --------------------------------------------------------------------------------------------------------
    // Helpers
    // --------------------------------------------------------------------------------------------------------

    function _excludeAllContracts() internal {
        excludeContract(address(dove01));
        excludeContract(address(fountain));
        excludeContract(address(routerL1));
        excludeContract(address(factoryL1));

        excludeContract(address(pair01Poly));
        excludeContract(address(feesAccumulator));
        excludeContract(address(factoryL2));
        excludeContract(address(routerL2));
    }

}
