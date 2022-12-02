// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

contract InterchainGasPaymasterMock {
    function payGasFor(bytes32 _messageId, uint32 _destinationDomain) external payable {
        _destinationDomain;
        _messageId;
    }
}
