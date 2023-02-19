// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./utils/TestUtils.sol";

import { 
    IDove,
    IL1Factory,
    IL1Router,
    IFountain,
    ISGHyperlaneConverter
} from "../src/L1/interfaces/L1Interfaces.sol";

import {
    IPair,
    IL2Factory,
    IL2Router,
    IFeesAccumulator,
    IVoucher,
    IStargateRouter
} from "../src/L2/interfaces/L2Interfaces.sol";

contract ProtocolActions is TestUtils {
    /// constants
    address internal USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address internal DAI  = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    /// Liquidity Functions
    // deposits
    // withdrawals

    /// Token Swap Functions
    // swapExactTokensForTokensSimple
    // swapExactTokensForTokens

    /// Sync to L2

    /// Sync to L1
    // standard
    // finalizeSyncFromL2

}

