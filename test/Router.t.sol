// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity ^0.8.15;

// import "forge-std/Test.sol";
// import "forge-std/Vm.sol";
// import "forge-std/console2.sol";

// import {Pair} from "src/L2/Pair.sol";
// import {Factory} from "src/L2/Factory.sol";
// import {Router} from "src/L2/Router.sol";
// import {TypeCasts} from "src/hyperlane/TypeCasts.sol";

// import {ERC20Mock} from "./mocks/ERC20Mock.sol";

// /// Only test AMM logic, nothing related to cross-chain.
// contract RouterTest is Test {
//     ERC20Mock token0L1;
//     ERC20Mock token1L1;

//     Router router;
//     Factory factory;
//     Pair pair;

//     ERC20Mock token0L2;
//     ERC20Mock token1L2;

//     uint256 reserve0 = 10**6 * 10**6;
//     uint256 reserve1 = 10**6 * 10**18;

//     address fees = address(0xfee);

//     function setUp() external {
//         token0L1 = new ERC20Mock("USDC", "USDC", 6); // USDC
//         token1L1 = new ERC20Mock("DAI", "DAI", 18); // DAI

//         token0L2 = new ERC20Mock("USDC", "USDC", 6); // USDC
//         token1L2 = new ERC20Mock("DAI", "DAI", 18); // DAI

//         factory = new Factory(fees, address(0), address(this), address(0), address(this), 0, 0);
//         pair = Pair(factory.createPair(address(token0L2), address(token1L2), address(token0L1), address(token1L1)));

//         token0L2.approve(address(pair), type(uint256).max);
//         token1L2.approve(address(pair), type(uint256).max);

//         token0L2.mint(address(this), 10**11);
//         token1L2.mint(address(this), 10**23);

//         pair.handle(0, TypeCasts.addressToBytes32(address(this)), abi.encode(reserve0, reserve1));
//     }

//     function testSingleSwap() external {
//         uint256 amount0In = 5000 * 10**6;
//         uint256 amount1Out = pair.getAmountOut(amount0In, address(token0L2));

//         token0L2.transfer(address(pair), amount0In);
//         pair.swap(0, amount1Out, address(0xBEEF), "");
//     }

//     function testTwoSwapsThenSyncThenSwap() external {
//         uint256 amount0In = 5000 * 10**6;

//         // first swap
//         uint256 amount1Out = pair.getAmountOut(amount0In, address(token0L2));
//         token0L2.transfer(address(pair), amount0In);
//         pair.swap(0, amount1Out, address(0xBEEF), "");

//         // second swap
//         amount1Out = pair.getAmountOut(amount0In, address(token0L2));
//         token0L2.transfer(address(pair), amount0In);
//         pair.swap(0, amount1Out, address(0xFEEB), "");

//         // sync to L1 AKA empties tokens held, reset vouchers counters, update reserves as they would have been on L1
//         /*
//             Napkin math
//             reserve0 = 10**(6+6) + 4999500000 + 4999500000
//                                    ^^IN-fees    ^^same
//             reserve1 = 10**(6+18) - 4999499687625020359591 - 4999495314379694889538
//                                    ^^^^ voucher             ^^^ voucher
//         */
//         pair.syncToL1(0, 0, 0, 0);
//         uint256 expectedR0 = 10**12 + 4999500000 + 4999500000;
//         uint256 expectedR1 = 10**24 - (4999499687625020359591 + 4999495314379694889538);
//         assertEq(pair.reserve0(), expectedR0);
//         assertEq(pair.reserve1(), expectedR1);
//     }

//     function testSomeSwapsThenSyncTwoWaysThenSwapsAgain() external {
//         uint256 amount0In = 5000 * 10**6;

//         // first swap
//         uint256 amount1Out = pair.getAmountOut(amount0In, address(token0L2));
//         token0L2.transfer(address(pair), amount0In);
//         pair.swap(0, amount1Out, address(0xBEEF), "");

//         // second swap
//         amount1Out = pair.getAmountOut(amount0In, address(token0L2));
//         token0L2.transfer(address(pair), amount0In);
//         pair.swap(0, amount1Out, address(0xFEEB), "");

//         pair.syncToL1(0, 0, 0, 0);
//         // pretend new liquidity was added on L1
//         uint256 newReserve0 = pair.reserve0() + 10**12;
//         uint256 newReserve1 = pair.reserve1() + 10**24;
//         pair.handle(0, TypeCasts.addressToBytes32(address(this)), abi.encode(newReserve0, newReserve1));

//         amount0In = 50000 * 10**6;
//         amount1Out = pair.getAmountOut(amount0In, address(token0L2));
//         token0L2.transfer(address(pair), amount0In);
//         pair.swap(0, amount1Out, address(0xCAFE), "");

//         assertEq(pair.reserve0(), newReserve0 + 49995000000);
//         assertEq(pair.reserve1(), newReserve1 - 49994190970921211315608);
//     }

//     receive() external payable {}
// }
