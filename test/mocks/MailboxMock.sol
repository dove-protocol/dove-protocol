// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

contract MailboxMock {
    event Dispatch(address sender, bytes payload);

    uint32 public immutable localDomain;

    constructor(uint32 _localDomain) {
        localDomain = _localDomain;
    }

    function dispatch(uint32 _destinationDomain, bytes32 _recipientAddress, bytes calldata _messageBody)
        external
        returns (bytes32)
    {
        bytes32 _id = bytes32(uint256(keccak256(abi.encodePacked(_destinationDomain, _recipientAddress, _messageBody))));
        emit Dispatch(msg.sender, _messageBody);
        return _id;
    }
}
