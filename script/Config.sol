pragma solidity ^0.8.15;

library Configs {
    address constant dove = 0x309EffB54b31C278Ed1c6F4bf85C6145b63Ee97f;

    address constant hlGasMaster = 0xF90cB82a76492614D07B82a7658917f3aC811Ac1;
    address constant hlMailbox = 0xCC737a94FecaeC165AbCf12dED095BB13F037685;

    /// Hyperlane DOMAINS
    uint32 constant L1_DOMAIN = 5; // ETH goerli
    uint32 constant ARB_DOMAIN = 421613; // ARB goerli
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
        uint16 sgChainId;
        address hlMailbox;
        address hlGasMaster;
        uint32 hlDomainId;
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
            dove: 0x309EffB54b31C278Ed1c6F4bf85C6145b63Ee97f,
            factory: 0x5fEeD6701497460a6ff6d48b90bf8F514a9C5e9B,
            arbiDomain: ARB_DOMAIN,
            polyDomain: POLY_DOMAIN,
            avaxDomain: AVAX_DOMAIN,
            pairArbi: 0x7De0Ca730B756a8953AA28D284069B8B2Db8C420,
            pairPoly: 0xccBf25F63db94B8215A18deAe0ca717c7B2817ca,
            pairAvax: 0x67C2e796dd93Cc711277164481ADD7baefF34184
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
            sgChainId: ARB_CHAIN_ID,
            hlMailbox: hlMailbox,
            hlGasMaster: hlGasMaster,
            hlDomainId: ARB_DOMAIN
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
            sgChainId: POLY_CHAIN_ID,
            hlMailbox: hlMailbox,
            hlGasMaster: hlGasMaster,
            hlDomainId: POLY_DOMAIN
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
            sgChainId: AVAX_CHAIN_ID,
            hlMailbox: hlMailbox,
            hlGasMaster: hlGasMaster,
            hlDomainId: AVAX_DOMAIN
        });
    }
}
