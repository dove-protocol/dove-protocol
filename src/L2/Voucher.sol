// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";

/// @notice A voucher ERC20.
contract Voucher is ERC20 {
    error OnlyOwner();

    /// @notice owner is the associated pair contract
    address public owner;

    /// @notice constructor
    /// @param _name name of token
    /// @param _symbol symbol of token
    /// @param _decimals decimals of token
    constructor(string memory _name, string memory _symbol, uint8 _decimals) ERC20(_name, _symbol, _decimals) {
        // set owner
        owner = msg.sender;
    }

    /// @notice mint vouchers
    function mint(address to, uint256 amount) public {
        if (msg.sender != owner) revert OnlyOwner();
        _mint(to, amount);
    }

    /// @notice burn vouchers
    function burn(address from, uint256 amount) public {
        if (msg.sender != owner) revert OnlyOwner();
        _burn(from, amount);
    }
}
