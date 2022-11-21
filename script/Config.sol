pragma solidity ^0.8.15;

library AMMConfigs {
    struct AMMConfig {
        address token0;
        address L1Token0;
        address token1;
        address L1Token1;
        address lzEndpoint;
        address stargateRouter;
        address L1Target;
        uint16 destChainId;
    }

    function getArbiGoerliConfig() internal pure returns (AMMConfig memory) {
        return AMMConfig(
            0x6aAd876244E7A1Ad44Ec4824Ce813729E5B6C291,
            0xDf0360Ad8C5ccf25095Aa97ee5F2785c8d848620,
            0x533046F316590C19d99c74eE661c6d541b64471C,
            0x5BCc22abEC37337630C0E0dd41D64fd86CaeE951,
            0x6aB5Ae6822647046626e83ee6dB8187151E1d5ab,
            0xb850873f4c993Ac2405A1AdD71F6ca5D4d4d6b4f,
            0x18e02D08CCEb8509730949954e904534768f1536,
            10121
        );
    }

    function getPolygonMumbaiConfig() internal pure returns (AMMConfig memory) {
        return AMMConfig(
            0x742DfA5Aa70a8212857966D491D67B09Ce7D6ec7,
            0xDf0360Ad8C5ccf25095Aa97ee5F2785c8d848620,
            0x6Fc340be8e378c2fF56476409eF48dA9a3B781a0,
            0x5BCc22abEC37337630C0E0dd41D64fd86CaeE951,
            0xf69186dfBa60DdB133E91E9A4B5673624293d8F8,
            0x817436a076060D158204d955E5403b6Ed0A5fac0,
            0x18e02D08CCEb8509730949954e904534768f1536,
            10121
        );
    }

    function getAvaxFujiConfig() internal pure returns (AMMConfig memory) {
        return AMMConfig(
            0x4A0D1092E9df255cf95D72834Ea9255132782318,
            0xDf0360Ad8C5ccf25095Aa97ee5F2785c8d848620,
            0x134Dc38AE8C853D1aa2103d5047591acDAA16682,
            0x5BCc22abEC37337630C0E0dd41D64fd86CaeE951,
            0x93f54D755A063cE7bB9e6Ac47Eccc8e33411d706,
            0x13093E05Eb890dfA6DacecBdE51d24DabAb2Faa1,
            0x18e02D08CCEb8509730949954e904534768f1536,
            10121
        );
    }
}

library FactoryConfig {
    function getETHGoerliConfig() internal pure returns (address lzEndpoint, address stargateRouter) {
        return (0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23, 0x7612aE2a34E5A363E137De748801FB4c86499152);
    }
}

library dAMMConfigs {
    struct dAMMConfig {
        address factory;
        address token0;
        address token1;
    }

    function getETHGoerliConfig() internal pure returns (dAMMConfig memory) {
        return dAMMConfig(
            0xD6425b4b8f749643AaCdeA24933453f7178D3AC1,
            0xDf0360Ad8C5ccf25095Aa97ee5F2785c8d848620,
            0x5BCc22abEC37337630C0E0dd41D64fd86CaeE951
        );
    }
}
