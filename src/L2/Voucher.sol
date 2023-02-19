// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";

/// @notice A voucher ERC20.
contract Voucher is ERC20 {
    error OnlyOwner();
    address public owner;

    constructor(string memory _name, string memory _symbol, uint8 _decimals)
        ERC20(_name, _symbol, _decimals) {
        owner = msg.sender;
    }

    function mint(address to, uint256 amount) public {
        if(msg.sender != owner) { revert OnlyOwner(); }
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public {
        if(msg.sender != owner) { revert OnlyOwner(); }
        _burn(from, amount);
    }
}
