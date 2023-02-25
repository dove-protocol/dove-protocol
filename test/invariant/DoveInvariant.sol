pragma solidity ^0.8.15;

import {StdInvariant} from "lib/utils/StdInvariant.sol";
import {TestBaseAssertions} from "../TestBaseAssertions.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract BaseInvariants is StdInvariant, TestBaseAssertions {
    //// State Variables

    uint256 internal setTimestamps;

    uint256[] internal timestamps;

    uint256 public currentTimestamp;

    /// Modifiers

    modifier useCurrentTimestamp() {
        vm.warp(currentTimestamp);
        _;
    }

    /// Invariant Tests
    /*
        Dove, 
        Pair, 
        token exchanges,
        syncing, 
        liquidity providing
    */

    function setCurrentTimestamp(uint256 currentTimestamp_) external {
        timestamps.push(currentTimestamp_);
        setTimestamps++;
        currentTimestamp = currentTimestamp_;
    }

    // --------------------------------------------------------------------------------------------------------
    // Dove Invariants
    // --------------------------------------------------------------------------------------------------------


}
