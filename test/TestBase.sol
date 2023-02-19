pragma solidity ^0.8.15;

import { Address, TestUtils } from "./utils/TestUtils.sol";
import "./ProtocolActions.sol";

contract TestBase is ProtocolActions {
    /// constants
    uint256 internal constant ONE_DAY   = 1 days;
    uint256 internal constant ONE_MONTH = ONE_YEAR / 12;
    uint256 internal constant ONE_YEAR  = 365 days;
    uint256 start;

    // L1 contracts
    address internal dove;

    // L2 contracts
    address internal pair;

    function setUp() public virtual {
        // initialize functions
        start = block.timestamp;
    }

    /// Initialize

    /// Helpers

    /// Actions

}