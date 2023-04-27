// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

library SGHyperlaneConverter {
    function sgToHyperlane(uint16 sgIdentifier) internal pure returns (uint32 domain) {
        if (sgIdentifier == 110) {
            // arbi
            return 42161;
        } else if (sgIdentifier == 111) {
            // optimism
            return 10;
        } else if (sgIdentifier == 109) {
            /// polygon
            return 137;
        }
    }
}
