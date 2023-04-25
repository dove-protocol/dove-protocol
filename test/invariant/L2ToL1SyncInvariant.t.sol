// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { L2ToL1SyncActor } from "./actors/L2ToL1SyncActor.sol";

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

    function setUp() external {
        _setUp();

        DoveBalanceOf0Before = ERC20(dove.token0()).balanceOf(address(dove));
        DoveBalanceOf1Before = ERC20(dove.token1()).balanceOf(address(dove));
        DoveClaimable0Before = dove.claimable0(BASE);
        DoveClaimable1Before = dove.claimable1(BASE);

        vm.selectFork(L2_FORK_ID);

        PairBalanceOf0Before = ERC20(pair.token0()).balanceOf(address(pair));
        PairBalanceOf1Before = ERC20(pair.token1()).balanceOf(address(pair));
        PairBalance0Before = pair.balance0();
        PairBalance1Before = pair.balance1();


        // deploy actor
        actor = new L2ToL1SyncActor();

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
        Minter.mintDAIL2(pair.token0(), address(actor), 2 ** 25);
        Minter.mintUSDCL2(pair.token1(), address(actor), 2 ** 13);

        targetSelector(fuzzSelector);
    }

    function invariant_dove_balanceOf() external {
        vm.selectFork(L1_FORK_ID);
        assertGe(
            ERC20(dove.token0()).balanceOf(address(dove)),
            DoveBalanceOf0Before
        );
        assertGe(
            ERC20(dove.token1()).balanceOf(address(dove)),
            DoveBalanceOf1Before
        );
    }

    function invariant_dove_claimable() external {
        vm.selectFork(L1_FORK_ID);
        assertGe(
            dove.claimable0(BASE),
            DoveClaimable0Before
        );
        assertGe(
            dove.claimable1(BASE),
            DoveClaimable1Before
        );
    }

    function invariant_pair_balanceOf() external {
        vm.selectFork(L2_FORK_ID);
        assertLe(
            ERC20(pair.token0()).balanceOf(address(pair)),
            PairBalanceOf0Before
        );
        assertLe(
            ERC20(pair.token1()).balanceOf(address(pair)),
            PairBalanceOf1Before
        );
    }

    function invariant_pair_balance() external {
        vm.selectFork(L2_FORK_ID);
        assertLe(
            ERC20(pair.token0()).balanceOf(address(pair)),
            PairBalanceOf0Before
        );
        assertLe(
            ERC20(pair.token1()).balanceOf(address(pair)),
            PairBalanceOf1Before
        );
    }
}