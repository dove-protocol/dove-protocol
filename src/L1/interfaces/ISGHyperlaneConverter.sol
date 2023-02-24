// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

interface ISGHyperlaneConverter {
    function sgToHyperlane(uint16 sgIdentifier) external pure returns (uint32 domain);
}
