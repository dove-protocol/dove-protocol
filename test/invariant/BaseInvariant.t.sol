pragma solidity ^0.8.15;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TestBaseAssertions} from "../TestBaseAssertions.sol";
import {Minter} from "../utils/Minter.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

import {L1ActorDoveRouter} from "./actors/L1ActorDoveRouter.sol";

contract BaseInvariant is StdInvariant, TestBaseAssertions {

    // --------------------------------------------------------------------------------------------------------
    // Dove Invariants
    // --------------------------------------------------------------------------------------------------------

    /// balance of the token inside dove01 must equal reserves
    function invariantDove01Solvency() internal {
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

    function invariantPair01PolySolvency() internal {
        assertEq(
            ERC20(pair01Poly.token0()).balanceOf(address(pair01Poly)),
            pair01Poly.reserve0()
        );
        assertEq(
            ERC20(pair01Poly.token1()).balanceOf(address(pair01Poly)),
            pair01Poly.reserve1()
        );
    }

    function invariantPair01PolyBalances() internal {
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

    // feeDistributor cumulative Balance should hold equal to all fees sent to it

    // --------------------------------------------------------------------------------------------------------
    // Helpers
    // --------------------------------------------------------------------------------------------------------

    function _excludeAllContracts() internal {
        // L1
        excludeContract(pauser);
        excludeContract(address(dove01));
        excludeContract(address(fountain));
        excludeContract(address(routerL1));
        excludeContract(address(factoryL1));
        excludeContract(L1SGRouter);
        excludeContract(address(gasMasterL1));
        excludeContract(address(mailboxL1));
        excludeContract(address(lzEndpointL1));
        excludeContract(address(L1Token0));
        excludeContract(address(L1Token1));
        // L2
        excludeContract(address(pair01Poly));
        excludeContract(address(feesAccumulator));
        excludeContract(address(factoryL2));
        excludeContract(address(routerL2));
        excludeContract(L2SGRouter);
        excludeContract(address(gasMasterL2));
        excludeContract(address(mailboxL2));
        excludeContract(address(lzEndpointL2));
        excludeContract(address(L2Token0));
        excludeContract(address(L2Token1));
    }

}
