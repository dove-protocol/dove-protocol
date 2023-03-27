// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

library SGHyperlaneConverter {
    error InvalidChain(uint16 chainId);

    function sgToHyperlane(uint16 sgIdentifier) internal pure returns (uint32 domain) {
        // TODO: add mainnet chains
        // arbitrum goerli
        if (sgIdentifier == 10143) {
            return 421613;
            // polygon mumbai
        } else if (sgIdentifier == 10109) {
            return 80001;
            // avalanche fuji
        } else if (sgIdentifier == 10106) {
            return 43113;
        } else {
            revert InvalidChain(sgIdentifier);
        }
    }
}
