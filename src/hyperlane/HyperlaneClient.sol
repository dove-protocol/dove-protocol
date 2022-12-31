// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {Owned} from "solmate/auth/Owned.sol";

import "./IMessageRecipient.sol";
import "./IMailbox.sol";
import "./IInterchainGasPaymaster.sol";

abstract contract HyperlaneClient is IMessageRecipient, Owned {
    IInterchainGasPaymaster public hyperlaneGasMaster;
    IMailbox public mailbox;

    modifier onlyMailbox() {
        require(msg.sender == address(mailbox), "NOT MAILBOX");
        _;
    }

    constructor(address _hyperlaneGasMaster, address _mailbox, address _owner) Owned(_owner) {
        hyperlaneGasMaster = IInterchainGasPaymaster(_hyperlaneGasMaster);
        mailbox = IMailbox(_mailbox);
    }

    function setHyperlaneGasMaster(address _hyperlaneGasMaster) external onlyOwner {
        hyperlaneGasMaster = IInterchainGasPaymaster(_hyperlaneGasMaster);
    }

    function setMailbox(address _mailbox) external onlyOwner {
        mailbox = IMailbox(_mailbox);
    }
}
