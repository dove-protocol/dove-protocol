// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { Dove } from "../../../src/L1/Dove.sol";
import { L1Router } from "../../../src/L1/L1Router.sol";
import { ERC20Mock } from "../../mocks/ERC20Mock.sol";

contract L1ActorDoveRouter {

    Dove public dove;
    L1Router public router;

    constructor (Dove _dove, L1Router _router) {
        dove = _dove;
        router = _router;
    }

    function deposit(
        uint256 _amountADesired, 
        uint256 _amountBDesired
    ) external {
        if(_amountADesired > ERC20Mock(dove.token0()).balanceOf(address(this)) || _amountBDesired > ERC20Mock(dove.token1()).balanceOf(address(this))) {
            return;
        }
        if(_amountADesired + _amountBDesired > ERC20Mock(dove.token0()).balanceOf(address(this)) + ERC20Mock(dove.token1()).balanceOf(address(this))) {
            return;
        }
        if(_amountADesired <= 10 ** 3 || _amountBDesired <= 10 ** 3) {
            return;
        }

        (uint256 _amountMinA, uint256 _amountMinB, uint256 liquidity) = 
            router.quoteAddLiquidity(dove.token0(), dove.token1(), _amountADesired, _amountBDesired);

        router.addLiquidity(
            dove.token0(),
            dove.token1(),
            _amountADesired,
            _amountBDesired,
            _amountMinA,
            _amountMinB,
            address(this),
            type(uint256).max
        );
    }


}