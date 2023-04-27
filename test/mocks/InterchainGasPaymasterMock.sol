// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

contract InterchainGasPaymasterMock {
   function payForGas(bytes32 _messageId, uint32 _destinationDomain, uint256 _gasAmount, address _refundAddress)
        external
        payable
    {
    }
}
