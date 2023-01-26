// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "./DoveBase.sol";
import "./mocks/SGAttacker.sol";

contract DoveAMMTest is DoveBase {
    function setUp() external {
        _setUp();
    }

    function testCannotBurnIfNotInitiated() external {
        // try to burn all liquidity directly, should fail
        (uint256 toRemove0, uint256 toRemove1) =
            routerL1.quoteRemoveLiquidity(dove.token0(), dove.token1(), dove.balanceOf(address(this)));
        dove.approve(address(routerL1), dove.balanceOf(address(this)));
        // make the calls before expectRevert
        address token0 = dove.token0();
        address token1 = dove.token1();
        uint256 amount = dove.balanceOf(address(this));
        vm.expectRevert("LOCKED_LIQUIDITY");
        routerL1.removeLiquidity(token0, token1, amount, toRemove0, toRemove1, address(this), block.timestamp + 1);
    }

    function testCanBurnIfInitiated() external {
        (uint256 toRemove0, uint256 toRemove1) =
            routerL1.quoteRemoveLiquidity(dove.token0(), dove.token1(), dove.balanceOf(address(this)));
        dove.approve(address(routerL1), dove.balanceOf(address(this)));
        vm.warp(block.timestamp + 31 days);
        routerL1.removeLiquidity(
            dove.token0(),
            dove.token1(),
            dove.balanceOf(address(this)),
            toRemove0,
            toRemove1,
            address(this),
            block.timestamp + 1
        );
    }

    function testMintingResetLock() external {
        (uint256 toRemove0, uint256 toRemove1) =
            routerL1.quoteRemoveLiquidity(dove.token0(), dove.token1(), dove.balanceOf(address(this)));
        dove.approve(address(routerL1), dove.balanceOf(address(this)));
        vm.warp(block.timestamp + 31 days);
        // add liquidity again, should reset lock
        (uint256 toAdd0, uint256 toAdd1,) =
            routerL1.quoteAddLiquidity(address(L1Token0), address(L1Token1), initialLiquidity0, initialLiquidity1); // 10M of each
        routerL1.addLiquidity(
            address(L1Token0),
            address(L1Token1),
            initialLiquidity0,
            initialLiquidity1,
            toAdd0,
            toAdd1,
            address(this),
            type(uint256).max
        );
        // make the calls before expectRevert
        address token0 = dove.token0();
        address token1 = dove.token1();
        uint256 amount = dove.balanceOf(address(this));
        vm.expectRevert("LOCKED_LIQUIDITY");
        routerL1.removeLiquidity(token0, token1, amount, toRemove0, toRemove1, address(this), block.timestamp + 1);
    }

    // If a user has unlocked tokens and send them to a user with locked tokens,
    // it won't unlock them
    function testSendingUnlockedTokensToLockedUserDoesntUnlock() external {
        // move forward, LP tokens of address(this) are unlocked at this point
        vm.warp(block.timestamp + 31 days);
        // add liquidity and send LP tokens to beef
        (uint256 toAdd0, uint256 toAdd1,) =
            routerL1.quoteAddLiquidity(address(L1Token0), address(L1Token1), initialLiquidity0, initialLiquidity1); // 10M of each
        routerL1.addLiquidity(
            address(L1Token0),
            address(L1Token1),
            initialLiquidity0,
            initialLiquidity1,
            toAdd0,
            toAdd1,
            address(0xbeef),
            type(uint256).max
        );
        // transfer unlocked tokens to beef
        dove.transfer(address(0xbeef), dove.balanceOf(address(this)));
        (uint256 toRemove0, uint256 toRemove1) =
            routerL1.quoteRemoveLiquidity(dove.token0(), dove.token1(), dove.balanceOf(address(0xbeef)));
        // beef should not be able to transfer or remove liquidity
        // make the calls before expectRevert
        address token0 = dove.token0();
        address token1 = dove.token1();
        uint256 amount = dove.balanceOf(address(this));
        vm.startBroadcast(address(0xbeef));
        vm.expectRevert("LOCKED_LIQUIDITY");
        routerL1.removeLiquidity(token0, token1, amount, toRemove0, toRemove1, address(this), block.timestamp + 1);
        vm.stopBroadcast();
    }
}
