// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "solady/utils/LibBit.sol";

contract Ingester {

    function getType(bytes calldata payload) public view returns (uint256 msgType) {
        bytes32 load1;
        bytes32 load2;
        bytes32 load3;
        assembly {
            load1 := calldataload(0x04)
            load2 := calldataload(0x24)
            load3 := calldataload(0x44)
            msgType := shr(253, load3)
        }
        console.logBytes32(load1);
        console.logBytes32(load2);
        console.logBytes32(load3);
    }
}

contract Playground is Test {

    function test_playground() public {
        bytes memory incoming = vm.parseBytes("0x600649c43485cd4f4d50e4edcc8e3b90d4969a8eda7d64c80000000000000000000000000000000000000000000000000000000000000006aaf7c8516d0c0000000000000000000000000000000000000000000000000018b84570022a20000000000000000000000000000000000000000000000000002ac59317b2e7340000000000000000000000000000e94f1fa4f27d9d288ffea234bb62e1fbc086ca0c00000000000000000000000000000000000000000000001166c51744e46400000000000000000000000000000000000000000000000000237412bef5a1780000000000000000000000000000000000000000000000000035816066a65e8c00000000000000000000000000007fa9385be102ac3eac297483dd6233d62b3e1496");
        Ingester ingester = new Ingester();
        ingester.getType(incoming);
    }
}