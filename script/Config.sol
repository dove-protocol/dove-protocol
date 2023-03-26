pragma solidity ^0.8.15;

library Configs {
    /// Current deployed contracts
    address constant dove = 0x13b156E036f6D91482b7136302A2D1fF0c5FDcF8;
    address constant factory = 0xF86761DC42adf7E7398A7DE4c2F6A2316eae807a;
    address constant router = 0x399CD1eB15a570BCd63d68FE6E073cB81730d9E4;
    address constant pairArbi = 0x78818F4784B9A1f272F4dcDE1ED09fF182bAF407;
    address constant pairPoly = 0x1aC3E28E97864296fE8b0fEA9cBCf77604bf0c4E;
    address constant pairAvax = 0x51fb7aDdE04fB8d45BF02B254C6DfbFA3aFaE916;
    address constant routerArbi = 0x88BDec3893364f43194eAbe01312cd3d49AC0d2B;
    address constant routerPoly = 0x3a11F5DD35790B0DcD80A0330FD20EAfBf0873Ae;
    address constant routerAvax = 0x4CCB891607C911Fd65e56D03bd850F9bB71e043C;

    address constant hlGasMaster = 0x8f9C3888bFC8a5B25AED115A82eCbb788b196d2a;
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
            arbiDomain: ARB_DOMAIN,
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
