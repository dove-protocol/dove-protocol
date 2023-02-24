// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./TestUtils.sol";

import {IDove} from "../../src/L1/interfaces/IDove.sol";
import {IFountain} from "../../src/L1/interfaces/IFountain.sol";
import {IL1Factory} from "../../src/L1/interfaces/IL1Factory.sol";
import {IL1Router} from "../../src/L1/interfaces/IL1Router.sol";

import {IPair} from "../../src/L2/interfaces/IPair.sol";
import {IL2Factory} from "../../src/L2/interfaces/IL2Factory.sol";
import {IL2Router} from "../../src/L2/interfaces/IL2Router.sol";
import {IFeesAccumulator} from "../../src/L2/interfaces/IFeesAccumulator.sol";
import {IVoucher} from "../../src/L2/interfaces/IVoucher.sol";
import {IStargateRouter} from "../../src/L2/interfaces/IStargateRouter.sol";

contract ProtocolActions is TestUtils {
    /// Liquidity Functions
    // deposit
    function addLiq(address _L1Router, address _dove, address _to, uint256 _amount0In, uint256 _amount1In)
        internal
        returns (uint256 amount0, uint256 amount1, uint256 liquidity)
    {
        (uint256 toAdd0, uint256 toAdd1,) =
            IL1Router(_L1Router).quoteAddLiquidity(IDove(_dove).token0(), IDove(_dove).token1(), _amount0In, _amount1In);

        (amount0, amount1, liquidity) = IL1Router(_L1Router).addLiquidity(
            IDove(_dove).token0(), IDove(_dove).token1(), _amount0In, _amount1In, toAdd0, toAdd1, _to, type(uint256).max
        );
    }

    /// withdrawal
    function removeLiq(address _L1Router, address _dove, address _to, uint256 liquidity)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 toRemove0, uint256 toRemove1) =
            IL1Router(_L1Router).quoteRemoveLiquidity(IDove(_dove).token0(), IDove(_dove).token1(), liquidity);

        (amount0, amount1) = IL1Router(_L1Router).removeLiquidity(
            IDove(_dove).token0(), IDove(_dove).token1(), liquidity, toRemove0, toRemove1, _to, type(uint256).max
        );
    }

    /// Token Swap Functions
    // swapExactTokensForTokensSimple
    function simpleSwapTokensForTokens(
        address _L2Router,
        address _pair,
        address _fromToken,
        address _to,
        uint256 amountIn
    ) internal {
        if (_fromToken == IPair(_pair).token0()) {
            uint256 amountOutMin =
                IL2Router(_L2Router).getAmountOut(amountIn, IPair(_pair).token0(), IPair(_pair).token1());

            IL2Router(_L2Router).swapExactTokensForTokensSimple(
                amountIn, amountOutMin, IPair(_pair).token0(), IPair(_pair).token1(), _to, type(uint256).max
            );
        } else {
            uint256 amountOutMin =
                IL2Router(_L2Router).getAmountOut(amountIn, IPair(_pair).token1(), IPair(_pair).token0());

            IL2Router(_L2Router).swapExactTokensForTokensSimple(
                amountIn, amountOutMin, IPair(_pair).token1(), IPair(_pair).token0(), _to, type(uint256).max
            );
        }
    }

    // function swapTokensForTokens() {}

    /// Sync to L2
    // function syncToL2(address _dove) internal {}

    /// Sync to L1
    // standard
    // finalizeSyncFromL2
}
