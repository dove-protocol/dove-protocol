pragma solidity ^0.8.15;

import "@/L2/interfaces/IStargateRouter.sol";
import "solmate/tokens/ERC20.sol";

import "forge-std/console.sol";

contract SGAttacker {
    uint16 syncID;

    function setSyncID(uint16 _syncID) public {
        syncID = _syncID;
    }

    function attack(
        address sgRouter,
        uint16 destChainId,
        uint256 srcPoolId,
        uint256 dstPoolId,
        address token,
        uint256 amount,
        address target
    ) public {
        ERC20(token).approve(sgRouter, amount);
        IStargateRouter(sgRouter).swap{value: 500 ether}(
            destChainId,
            srcPoolId,
            dstPoolId,
            payable(msg.sender),
            amount,
            0,
            IStargateRouter.lzTxObj(100000, 0, "0x"),
            abi.encodePacked(target),
            abi.encode(syncID)
        );
    }
}
