// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

library SGHyperlaneConverter {
    function sgToHyperlane(uint16 sgIdentifier) internal pure returns (uint32 domain) {
        if (sgIdentifier == 110) {
            // arbi
            return 0x617262;
        } else if (sgIdentifier == 111) {
            // optimism
            return 0x6f70;
        } else if (sgIdentifier == 109) {
            /// polygon
            return 0x706f6c79;
        }
    }
}
