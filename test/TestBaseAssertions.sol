// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { BalanceAssertions } from "./BalanceAssertions.sol";
import { TestBase }          from "./TestBase.sol";

import { Dove } from "../src/L1/Dove.sol";
import { Pair } from "../src/L2/Pair.sol";
import { Codec } from "../src/Codec.sol";


contract TestBaseAssertions is TestBase, BalanceAssertions {

    
    // --------------------------------------------------------------------------------------------------------//
    // State Assertion Functions
    // --------------------------------------------------------------------------------------------------------//

    /// Dove

    function assertDoveBurnClaims(
        address user,
        Dove.BurnClaim memory burnClaim,
        uint256 _amount0, 
        uint256 _amount1
    ) internal {
        assertEq(burnClaim.amount0, _amount0);
        assertEq(burnClaim.amount1, _amount1);
    }

    // assert state of earmarked tokens from "domainID" within "dove"
    function assertDoveMarkedTokens(
        Dove dove, 
        uint32 domainID, 
        uint256 markedAmount0, 
        uint256 markedAmount1
    ) internal {
        assertEq(dove.marked0(domainID), markedAmount0);
        assertEq(dove.marked1(domainID), markedAmount1);
    }

    // assert claimable tokens for "owner" within "dove"
    function assertDoveSupplyIndex(
        Dove dove, 
        address recipient, 
        uint256 supplyIndex0, 
        uint256 supplyIndex1
    ) internal {
        assertEq(dove.supplyIndex0(recipient), supplyIndex0);
        assertEq(dove.supplyIndex1(recipient), supplyIndex1);
    }

    // assert claimable tokens for "owner" within "dove"
    function assertDoveClaimable(
        Dove dove, 
        address owner, 
        uint256 claimable0, 
        uint256 claimable1
    ) internal {
        assertEq(dove.claimable0(owner), claimable0);
        assertEq(dove.claimable1(owner), claimable1);
    }

    // assert index state of "dove"
    function assertDoveIndex(Dove dove, uint256 index0, uint256 index1) internal {
        assertEq(dove.index0(), index0, "index[0]");
        assertEq(dove.index1(), index1, "index[1]");
    }

    // assert reserve state of "dove"
    function assertDoveReserves(Dove dove, uint256 reserve0, uint256 reserve1) internal {
        assertEq(dove.reserve0(), reserve0);
        assertEq(dove.reserve1(), reserve1);
    }

    /// Pair

    // assert reserve state of "pair" from "forkID"
    function assertPairReserves(
        Pair pair, 
        uint256 forkID, 
        uint256 reserve0, 
        uint256 reserve1
    ) internal {
        vm.selectFork(forkID);
        assertEq(pair.reserve0(), reserve0);
        assertEq(pair.reserve1(), reserve1);
    }

    // assert reserveCumulativeLast state of "pair" from "forkID"
    function assertPairReserveCumulativeLast(
        Pair pair, 
        uint256 forkID, 
        uint256 _reserveCumulative0, 
        uint256 _reserveCumulative1
    ) internal {
        vm.selectFork(forkID);
        assertEq(pair.reserve0CumulativeLast(), _reserveCumulative0);
        assertEq(pair.reserve1CumulativeLast(), _reserveCumulative1);
    }

    // assert reserve state of "pair" from "forkID"
    function assertPairBalances(
        Pair pair, 
        uint256 forkID, 
        uint256 _balance0, 
        uint256 _balance1
    ) internal {
        vm.selectFork(forkID);
        assertEq(pair.balance0(), _balance0);
        assertEq(pair.balance1(), _balance1);
        assertGe(pair.balance0(), pair.reserve0());
        assertGe(pair.balance1(), pair.reserve1());
    }

    /// Sync

    // assert state of "_sync" within "syncID" from "domainID" within "dove" is correct
    function assertDoveSyncContents(
        Dove.Sync memory _sync,
        uint256 tokensForDoveA,
        uint256 earmarkedAmountA,
        uint256 pairBalanceA,
        uint256 tokensForDoveB,
        uint256 earmarkedAmountB,
        uint256 pairBalanceB
    ) internal {
        assertEq(_sync.partialSyncA.tokensForDove, tokensForDoveA);
        assertEq(_sync.partialSyncA.earmarkedAmount, tokensForDoveA);
        assertEq(_sync.partialSyncA.pairBalance, tokensForDoveA);
        assertEq(_sync.partialSyncB.tokensForDove, tokensForDoveA);
        assertEq(_sync.partialSyncB.earmarkedAmount, tokensForDoveA);
        assertEq(_sync.partialSyncB.pairBalance, tokensForDoveA);
    }

    
}