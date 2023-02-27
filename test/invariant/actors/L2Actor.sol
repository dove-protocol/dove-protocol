// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { Pair } from "../../../src/L2/Pair.sol";
import { L2Router } from "../../../src/L2/L2Router.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

contract L2Actor is StdUtils {

    Pair public pair;
    L2Router public router;

    constructor (address _pair, address _router) {
        pair = Pair(_pair);
        router = L2Router(_router);
    }

    /*function swap(uint256 _amountIn) external {
        uint256 boundedAmountIn = bound(_amountIn, 1, ERC20Mock(pair.token0()).balanceOf(address(this)));

        uint256 amountOut = pair.getAmountOut(_amountInBounded, tokenIn, tokenOut);

        //router.swapExactTokensForTokensSimple(amountIn, amountOutMin,tokenFrom,tokenTo,to,deadline)
    }*/
}