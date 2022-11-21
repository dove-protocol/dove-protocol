// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";

/// @notice A voucher ERC20.
contract Voucher is ERC20, Owned {

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    )
    ERC20(_name, _symbol, _decimals)
    Owned(msg.sender)
    {
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) public onlyOwner {
        _burn(from, amount);
    }

    

}