// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

library SGHyperlaneConverter {
    error InvalidChain(uint16 chainId);

    /// @notice convert stargate identifier (chain id) to hyperlane domain
    function sgToHyperlane(uint16 sgIdentifier) internal pure returns (uint32 domain) {
        // TODO: add mainnet chains
        if (sgIdentifier == 10143) {
            // arbitrum goerli
            return 421613;
        } else if (sgIdentifier == 10109) {
            // polygon mumbai
            return 80001;
        } else if (sgIdentifier == 10106) {
            // avalanche fuji
            return 43113;
        } else if (sgIdentifier == 110) {
            // arbi
            return 42161;
        } else if (sgIdentifier == 111) {
            // optimism
            return 10;
        } else if (sgIdentifier == 109) {
            /// polygon
            return 137;
        } else {
            revert InvalidChain(sgIdentifier);
        }
    }
}
