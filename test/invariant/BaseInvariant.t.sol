pragma solidity ^0.8.15;

import {DoveBase} from "../DoveBase.sol";
import {Minter} from "../utils/Minter.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract BaseInvariant is DoveBase {

    // --------------------------------------------------------------------------------------------------------
    // Dove Invariants
    // --------------------------------------------------------------------------------------------------------

    /// balance of the token inside dove must equal reserves
    function invariantDoveSolvency() internal {
        assertEq(
            ERC20(dove.token0()).balanceOf(address(dove)),
            dove.reserve0()
        );
        assertEq(
            ERC20(dove.token1()).balanceOf(address(dove)),
            dove.reserve1()
        );
    } 

    // --------------------------------------------------------------------------------------------------------
    // Pair Invariants
    // --------------------------------------------------------------------------------------------------------

    function invariantPairSolvency() internal {
        vm.selectFork(L2_FORK_ID);
        assertEq(
            ERC20(pair.token0()).balanceOf(address(pair)),
            pair.reserve0()
        );
        assertEq(
            ERC20(pair.token1()).balanceOf(address(pair)),
            pair.reserve1()
        );
    }

    function invariantPairBalances() internal {
        vm.selectFork(L2_FORK_ID);
        assertLe(
            pair.balance0(),
            pair.reserve0()
        );
        assertLe(
            pair.balance1(),
            pair.reserve1()
        );
    }
}
