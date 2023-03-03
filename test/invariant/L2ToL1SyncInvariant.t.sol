// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { L2ToL1SyncActor } from "./actors/L2toL1SyncActor.sol";

import { BaseInvariant } from "./BaseInvariant.t.sol";
import { Minter } from "../utils/Minter.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

contract L2ToL1SyncInvariant is BaseInvariant {
    /// state variables
    // Dove
    uint256 public DoveBalanceOf0Before;
    uint256 public DoveBalanceOf1Before;
    uint256 public DoveClaimable0Before;
    uint256 public DoveClaimable1Before;
    // Pair
    uint256 public PairBalanceOf0Before;
    uint256 public PairBalanceOf1Before;
    uint256 public PairBalance0Before;
    uint256 public PairBalance1Before;

    L2ToL1SyncActor public actor;

    function setUp() public override {
        super.setUp();

        DoveBalanceOf0Before = ERC20(dove01.token0()).balanceOf(address(dove01));
        DoveBalanceOf1Before = ERC20(dove01.token1()).balanceOf(address(dove01));
        DoveClaimable0Before = dove01.claimable0(BASE);
        DoveClaimable1Before = dove01.claimable1(BASE);

        PairBalanceOf0Before = ERC20(pair01Poly.token0()).balanceOf(address(pair01Poly));
        PairBalanceOf1Before = ERC20(pair01Poly.token1()).balanceOf(address(pair01Poly));
        PairBalance0Before = pair01Poly.balance0();
        PairBalance1Before = pair01Poly.balance1();


        // deploy actor
        actor = new L2ToL1SyncActor(address(pair01Poly), address(dove01), address(routerL2));

        // selectors for actor
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = bytes4(0x5249f13e);
        selectors[1] = bytes4(0xdf1b3a32);
        selectors[2] = bytes4(0x6220bc9e);
        FuzzSelector memory fuzzSelector = FuzzSelector({
        addr: address(actor),
        selectors: selectors
        });

        // give actor pool tokens
        Minter.mintDAIL1(pair01Poly.token0(), address(actor), 2 ** 25);
        Minter.mintUSDCL1(pair01Poly.token1(), address(actor), 2 ** 13);

        targetSelector(fuzzSelector);
    }

    function invariant_dove_balanceOf() external {
        assertGe(
            ERC20(dove01.token0()).balanceOf(address(dove01)),
            DoveBalanceOf0Before
        );
        assertGe(
            ERC20(dove01.token1()).balanceOf(address(dove01)),
            DoveBalanceOf1Before
        );
    }

    function invariant_dove_claimable() external {
        assertGe(
            dove01.claimable0(BASE),
            DoveClaimable0Before
        );
        assertGe(
            dove01.claimable1(BASE),
            DoveClaimable1Before
        );
    }

    function invariant_pair_balanceOf() external {
        assertLe(
            ERC20(pair01Poly.token0()).balanceOf(address(pair01Poly)),
            PairBalanceOf0Before
        );
        assertLe(
            ERC20(pair01Poly.token1()).balanceOf(address(pair01Poly)),
            PairBalanceOf1Before
        );
    }

    function invariant_pair_balance() external {
        assertLe(
            ERC20(pair01Poly.token0()).balanceOf(address(pair01Poly)),
            PairBalanceOf0Before
        );
        assertLe(
            ERC20(pair01Poly.token1()).balanceOf(address(pair01Poly)),
            PairBalanceOf1Before
        );
    }
}