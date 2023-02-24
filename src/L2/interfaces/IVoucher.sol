pragma solidity ^0.8.15;

interface IVoucher {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}
