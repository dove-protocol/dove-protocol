pragma solidity ^0.8.15;

library Configs {
    /// Current deployed contracts
    address constant dove = 0x4cEe61a7641390b71225cD64FB6cE7CA30E7e151;
    address constant factory = 0xA3bB990Ae34B504FA02D2aEf75A7626bf40bA3d5;
    address constant router = 0x5Aebb6E8f23782Af574232D5E0eA95Ec1EEa3587;
    address constant pairArbi = 0xD348BcCdbB17d7ff2A3D48952aa4f2886F151256;
    address constant pairPoly = 0xDA3fEC084E9958268F650dA21817860ba2D2988d;
    address constant pairAvax = 0x3c30d2c818ad1fe7B44595A3CF264A97dcE566cE;
    address constant routerArbi = 0x0eCd916D0DD87433bf2772D8d6363c7A770a5Ab5;
    address constant routerPoly = 0xa9582De37b16C0d28E89c2F02a66692642F3B487;
    address constant routerAvax = 0x0656AB5c74a804076ce027ae5BB3eF91dc45f665;

    address constant hlGasMaster = 0x8f9C3888bFC8a5B25AED115A82eCbb788b196d2a;
    address constant hlMailbox = 0xCC737a94FecaeC165AbCf12dED095BB13F037685;

    /// Hyperlane DOMAINS
    uint32 constant L1_DOMAIN = 5; // ETH goerli
    uint32 constant ARBI_DOMAIN = 421613; // ARB goerli
    uint32 constant POLY_DOMAIN = 80001; // POLY mumbai
    uint32 constant AVAX_DOMAIN = 43113; // AVAX fuji

    /// Stargate BRIDGES
    // L1 goerli
    address constant sgBridgeL1 = 0xE6612eB143e4B350d55aA2E229c80b15CA336413;
    // ARB goerli
    address constant sgBridgeARB = 0xd43cbCC7642C1Df8e986255228174C2cca58d65b;
    // POLY mumbai
    address constant sgBridgePOLY = 0x629B57D89b1739eE1C0c0fD9eab426306e11cF42;
    // AVAX fuji
    address constant sgBridgeAVAX = 0x29fBC4E4092Db862218c62a888a00F9521619230;

    /// Stargate ROUTERS
    // L1 goerli
    address constant sgRouterL1 = 0x7612aE2a34E5A363E137De748801FB4c86499152;
    // ARB goerli
    address constant sgRouterARB = 0xb850873f4c993Ac2405A1AdD71F6ca5D4d4d6b4f;
    // POLY mumbai
    address constant sgRouterPOLY = 0x817436a076060D158204d955E5403b6Ed0A5fac0;
    // AVAX fuji
    address constant sgRouterAVAX = 0x13093E05Eb890dfA6DacecBdE51d24DabAb2Faa1;

    /// Chain IDs
    uint16 constant L1_CHAIN_ID = 10121; // ETH goerli
    uint16 constant ARB_CHAIN_ID = 10143; // ARB goerli
    uint16 constant POLY_CHAIN_ID = 10109; // POLY mumbai
    uint16 constant AVAX_CHAIN_ID = 10106; // AVAX fuji

    /// TOKENS
    // L1 goerli
    address constant USDT = 0x5BCc22abEC37337630C0E0dd41D64fd86CaeE951;
    address constant USDC = 0xDf0360Ad8C5ccf25095Aa97ee5F2785c8d848620;
    // ARB goerli
    address constant ARB_USDT = 0x533046F316590C19d99c74eE661c6d541b64471C;
    address constant ARB_USDC = 0x6aAd876244E7A1Ad44Ec4824Ce813729E5B6C291;
    // POLY mumbai
    address constant POLY_USDT = 0x6Fc340be8e378c2fF56476409eF48dA9a3B781a0;
    address constant POLY_USDC = 0x742DfA5Aa70a8212857966D491D67B09Ce7D6ec7;
    // AVAX fuji
    address constant AVAX_USDT = 0x134Dc38AE8C853D1aa2103d5047591acDAA16682;
    address constant AVAX_USDC = 0x4A0D1092E9df255cf95D72834Ea9255132782318;

    struct AMMConfig {
        address dove;
        address token0;
        address L1Token0;
        address token1;
        address L1Token1;
        address sgRouter;
        address sgBridge;
        uint16 sgDestChainId;
        address hlMailbox;
        address hlGasMaster;
        uint32 hlDestDomainId;
    }

    struct dAMMConfig {
        address hlMailbox;
        address hlGasMaster;
        uint16 arbiChainId;
        uint16 polyChainId;
        uint16 avaxChainId;
        address sgBridgeArbi;
        address sgBridgePoly;
        address sgBridgeAvax;
        address sgBridgeL1;
        address sgRouterArbi;
        address sgRouterPoly;
        address sgRouterAvax;
        address sgRouterL1;
    }

    struct dAMMDeployedConfig {
        address dove;
        address factory;
        address router;
        address token0;
        address token1;
        uint32 arbiDomain;
        uint32 polyDomain;
        uint32 avaxDomain;
        address pairArbi;
        address pairPoly;
        address pairAvax;
    }

    function getETHGoerliDAMMConfig() internal pure returns (dAMMConfig memory) {
        return dAMMConfig(
            hlMailbox,
            hlGasMaster,
            ARB_CHAIN_ID,
            POLY_CHAIN_ID,
            AVAX_CHAIN_ID,
            sgBridgeARB,
            sgBridgePOLY,
            sgBridgeAVAX,
            sgBridgeL1,
            sgRouterARB,
            sgRouterPOLY,
            sgRouterAVAX,
            sgRouterL1
        );
    }

    function getETHGoerliDAMMDeployedConfig() internal pure returns (dAMMDeployedConfig memory) {
        return dAMMDeployedConfig({
            dove: dove,
            factory: factory,
            router: router,
            token0: USDT,
            token1: USDC,
            arbiDomain: ARBI_DOMAIN,
            polyDomain: POLY_DOMAIN,
            avaxDomain: AVAX_DOMAIN,
            pairArbi: pairArbi,
            pairPoly: pairPoly,
            pairAvax: pairAvax
        });
    }

    function getArbiGoerliConfig() internal pure returns (AMMConfig memory) {
        return AMMConfig({
            dove: dove,
            token0: ARB_USDT,
            L1Token0: USDT,
            token1: ARB_USDC,
            L1Token1: USDC,
            sgRouter: sgRouterARB,
            sgBridge: sgBridgeARB,
            sgDestChainId: L1_CHAIN_ID,
            hlMailbox: hlMailbox,
            hlGasMaster: hlGasMaster,
            hlDestDomainId: L1_DOMAIN
        });
    }

    function getPolygonMumbaiConfig() internal pure returns (AMMConfig memory) {
        return AMMConfig({
            dove: dove,
            token0: POLY_USDT,
            L1Token0: USDT,
            token1: POLY_USDC,
            L1Token1: USDC,
            sgRouter: sgRouterPOLY,
            sgBridge: sgBridgePOLY,
            sgDestChainId: L1_CHAIN_ID,
            hlMailbox: hlMailbox,
            hlGasMaster: hlGasMaster,
            hlDestDomainId: L1_DOMAIN
        });
    }

    function getAvaxFujiConfig() internal pure returns (AMMConfig memory) {
        return AMMConfig({
            dove: dove,
            token0: AVAX_USDT,
            L1Token0: USDT,
            token1: AVAX_USDC,
            L1Token1: USDC,
            sgRouter: sgRouterAVAX,
            sgBridge: sgBridgeAVAX,
            sgDestChainId: L1_CHAIN_ID,
            hlMailbox: hlMailbox,
            hlGasMaster: hlGasMaster,
            hlDestDomainId: L1_DOMAIN
        });
    }
}