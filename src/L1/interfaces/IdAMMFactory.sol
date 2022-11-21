pragma solidity >=0.5.0;

interface IdAMMFactory {
    event dAMMCreated(address indexed token0, address indexed token1, address dAMM, uint);

    function getdAMM(address tokenA, address tokenB) external view returns (address dAMM);
    function alldAMMs(uint) external view returns (address dAMM);
    function alldAMMsLength() external view returns (uint);
    function lzEndpoint() external view returns (address);
    function stargateRouter() external view returns (address);
    function admin() external view returns (address);
    function createdAMM(address tokenA, address tokenB) external returns (address dAMM);
}