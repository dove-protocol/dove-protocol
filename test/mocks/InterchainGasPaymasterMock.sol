// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

contract InterchainGasPaymasterMock {
    function payForGas(bytes32 _messageId, uint32 _destinationDomain, uint256 _gasAmount, address _refundAddress)
        external
        payable
    {
        // uint256 _requiredPayment = quoteGasPayment(
        //     _destinationDomain,
        //     _gasAmount
        // );
        // require(
        //     msg.value >= _requiredPayment,
        //     "insufficient interchain gas payment"
        // );
        // uint256 _overpayment = msg.value - _requiredPayment;
        // if (_overpayment > 0) {
        //     (bool _success, ) = _refundAddress.call{value: _overpayment}("");
        //     require(_success, "Interchain gas payment refund failed");
        // }

        // emit GasPayment(_messageId, _gasAmount, _requiredPayment);
    }
}
