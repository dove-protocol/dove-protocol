// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

interface USDL1 {
    // FOR USDC
    function masterMinter() external view returns (address);
    function configureMinter(address, uint256) external returns (bool);
    function mint(address, uint256) external;

    // FOR DAI
    // uses mint too
}

interface USDL2 {
    // FOR USDC
    function deposit(address, bytes calldata) external;
    function bridgeMint(address, uint256) external;
    function gatewayAddress() external view returns (address);

    // FOR DAI
    // just like USDC
}

contract Helper is Test {
    function mintUSDCL1(address _token, address _to, uint256 _amount) public {
        USDL1 USDC = USDL1(_token);
        vm.startBroadcast(USDC.masterMinter());
        USDC.configureMinter(USDC.masterMinter(), type(uint256).max);
        USDC.mint(_to, _amount);
        vm.stopBroadcast();
    }

    function mintUSDCL2(address _token, address _to, uint256 _amount) public {
        USDL2 USDC = USDL2(_token);
        vm.startBroadcast(0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa);
        USDC.deposit(_to, abi.encode(_amount));
        vm.stopBroadcast();
    }

    function mintDAIL1(address _token, address _to, uint256 _amount) public {
        USDL1 DAI = USDL1(_token);
        vm.store(_token, keccak256(abi.encode(address(this), uint256(0))), bytes32(uint256(1)));
        DAI.mint(_to, _amount);
    }

    function mintDAIL2(address _token, address _to, uint256 _amount) public {
        USDL2 DAI = USDL2(_token);
        vm.startBroadcast(0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa);
        DAI.deposit(_to, abi.encode(_amount));
        vm.stopBroadcast();
    }
}
