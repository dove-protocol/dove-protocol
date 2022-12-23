// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Owned} from "solmate/auth/Owned.sol";

import "../hyperlane/TypeCasts.sol";

import "./interfaces/IStargateReceiver.sol";
import "../hyperlane/HyperlaneClient.sol";

import "../MessageType.sol";

contract Dove is IStargateReceiver, Owned, HyperlaneClient, ERC20 {
    /*###############################################################
                            CONSTANTS
    ###############################################################*/

    /*###############################################################
                            STRUCTS
    ###############################################################*/

    struct PartialSync {
        address token;
        uint256 bridgedAmount;
        uint256 earmarkedAmount;
    }

    /*###############################################################
                            STORAGE
    ###############################################################*/

    address public stargateRouter;

    address public token0;
    address public token1;

    uint256 public reserve0;
    uint256 public reserve1;
    /// @notice earmarked tokens
    mapping(uint32 => uint256) public marked0;
    mapping(uint32 => uint256) public marked1;
    /// @notice domain id [hyperlane] => PartialSync
    mapping(uint32 => PartialSync) public partialSyncs;

    mapping(uint32 => bytes32) public trustedRemoteLookup;
    mapping(uint16 => bytes) public sgTrustedBridge;

    function addTrustedRemote(uint32 origin, bytes32 sender) external onlyOwner {
        trustedRemoteLookup[origin] = sender;
    }

    function addStargateTrustedBridge(uint16 chainId, address remote, address local) external onlyOwner {
        sgTrustedBridge[chainId] = abi.encodePacked(remote, local);
    }

    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/

    constructor(address _token0, address _token1, address _hyperlaneGasMaster, address _mailbox, address _sgRouter)
        ERC20("Dove", "DVE", 18)
        HyperlaneClient(_hyperlaneGasMaster, _mailbox, msg.sender)
    {
        token0 = _token0;
        token1 = _token1;
        stargateRouter = _sgRouter;
    }

    /*###############################################################
                            LIQUIDITY LOGIC
    ###############################################################*/

    /// @notice Add liquidity to a pool.
    function provide(uint256 amount0, uint256 amount1) public {
        // transfer tokens from user to pool
        ERC20(token0).transferFrom(msg.sender, address(this), amount0);
        ERC20(token1).transferFrom(msg.sender, address(this), amount1);
        if (reserve0 > 0 || reserve1 > 0) {
            require((reserve0 * amount1 == reserve1 * amount0), "PROVIDE:INVALID RATIO");
        }

        uint256 shares = FixedPointMathLib.sqrt(amount0 * amount1);
        require(shares > 0, "DAMM:PROVIDE: SHARES=0");
        _mint(msg.sender, shares);
        reserve0 += amount0;
        reserve1 += amount1;
    }

    /// @notice Remove liquidity from a pool.
    function withdraw(uint256 shares) public {
        uint256 balance0 = ERC20(token0).balanceOf(address(this));
        uint256 balance1 = ERC20(token1).balanceOf(address(this));

        uint256 amount0 = (shares * balance0) / totalSupply;
        uint256 amount1 = (shares * balance1) / totalSupply;
        require(amount0 > 0 && amount1 > 0, "amount = 0");

        _burn(msg.sender, shares);

        reserve0 -= amount0;
        reserve1 -= amount1;

        ERC20(token0).transfer(msg.sender, amount0);
        ERC20(token1).transfer(msg.sender, amount1);
    }

    /*###############################################################
                            SYNCING LOGIC
    ###############################################################*/

    /// @notice Callback used by Stargate when doing a cross-chain swap.
    /// @param _srcChainId The chainId of the remote chain.
    /// @param _srcAddress The address of the remote chain.
    /// @param _token The token contract on the local chain.
    /// @param _bridgedAmount The quantity of local _token tokens.
    /// @param _payload Extra payload.
    function sgReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint256, /*_nonce*/
        address _token,
        uint256 _bridgedAmount,
        bytes memory _payload
    ) external override {
        require(msg.sender == stargateRouter, "NOT STARGATE");
        require(keccak256(_srcAddress) == keccak256(sgTrustedBridge[_srcChainId]), "NOT TRUSTED");
        (uint256 earmarkedAmount, uint256 exactBridgedAmount, uint32 srcDomain) =
            abi.decode(_payload, (uint256, uint256, uint32));
        // check if already partial sync
        // @note Maybe enforce check that second partial sync is "pair" of first one
        PartialSync memory partialSync = partialSyncs[srcDomain];
        if (partialSync.token == address(0)) {
            partialSyncs[srcDomain] = PartialSync(_token, exactBridgedAmount, earmarkedAmount);
        } else {
            // can proceed with full sync
            if (partialSync.token == token0) {
                _syncFromL2(
                    srcDomain,
                    partialSync.bridgedAmount,
                    exactBridgedAmount,
                    partialSync.earmarkedAmount,
                    earmarkedAmount
                );
            } else {
                _syncFromL2(
                    srcDomain,
                    exactBridgedAmount,
                    partialSync.bridgedAmount,
                    earmarkedAmount,
                    partialSync.earmarkedAmount
                );
            }
            // reset
            delete partialSyncs[_srcChainId];
        }
    }

    function handle(uint32 origin, bytes32 sender, bytes calldata payload) external onlyInbox {
        // check if message is from trusted remote
        require(trustedRemoteLookup[origin] == sender, "NOT TRUSTED");
        uint256 messageType = abi.decode(payload, (uint256));
        if (messageType == MessageType.BURN_VOUCHER) {
            // token address should be either L1 address of token0 or token1
            (, address token, address user, uint256 amount) = abi.decode(payload, (uint256, address, address, uint256));
            _completeVoucherBurn(origin, token, user, amount);
        }
    }

    function syncL2(uint32 destinationDomain, address amm) external payable {
        bytes memory payload = abi.encode(reserve0, reserve1);
        bytes32 id = mailbox.dispatch(destinationDomain, TypeCasts.addressToBytes32(amm), payload);
        // pay for gas
        hyperlaneGasMaster.payGasFor{value: msg.value}(id, destinationDomain);
    }

    /*###############################################################
                            INTERNAL FUNCTIONS
    ###############################################################*/

    /// @notice Completes a voucher burn initiated on the L2.
    /// @dev Checks if user is able to burn or not should be done on L2 beforehand.
    /// @param srcDomain The domain id of the remote chain.
    /// @param token The token contract on the local chain.
    /// @param user The user who initiated the burn.
    /// @param amount The quantity of local _token tokens.
    function _completeVoucherBurn(uint32 srcDomain, address token, address user, uint256 amount) internal {
        require(token == token0 || token == token1, "BURN:INVALID TOKEN");
        // update earmarked tokens
        if (token == token0) {
            marked0[srcDomain] -= amount;
        } else {
            marked1[srcDomain] -= amount;
        }
        ERC20(token).transfer(user, amount);
    }

    /// @notice Syncing implies bridging the tokens from the L2 back to the L1.
    /// @notice These tokens are simply added back to the reserves.
    /// @dev    This should be an authenticated call, only callable by the operator.
    /// @dev    The sync should be followed by a sync on the L2.
    function _syncFromL2(uint32 srcDomain, uint256 bridged0, uint256 bridged1, uint256 earmarked0, uint256 earmarked1)
        internal
    {
        uint256 newreserve0 = reserve0 + bridged0 - (earmarked0 - marked0[srcDomain]);
        uint256 newreserve1 = reserve1 + bridged1 - (earmarked1 - marked1[srcDomain]);
        reserve0 = newreserve0;
        reserve1 = newreserve1;
        marked0[srcDomain] = earmarked0;
        marked1[srcDomain] = earmarked1;
    }

    /*###############################################################
                            VIEW FUNCTIONS
    ###############################################################*/
}
