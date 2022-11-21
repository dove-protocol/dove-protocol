// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import "solmate/utils/FixedPointMathLib.sol";
import "./interfaces/IdAMMFactory.sol";
import "./interfaces/IStargateReceiver.sol";
import "../interfaces/ILayerZeroReceiver.sol";
import "../interfaces/ILayerZeroEndpoint.sol";
import "../MessageType.sol";

/// @notice A dAMM prototype.
contract dAMM is IStargateReceiver, ILayerZeroReceiver, ERC20 {
    /*/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\
                            CONSTANTS
    /|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\*/
    uint256 immutable MINIMUM_HF = 9 * 10 ** 8; // 0.9

    /*/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\
                            STRUCTS
    /|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\*/

    struct PartialSync {
        address token;
        uint256 bridgedAmount;
        uint256 earmarkedAmount;
    }

    /*/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\
                            STORAGE
    /|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\*/

    address public factory;
    address public token0;
    address public token1;

    uint256 public reserve0;
    uint256 public reserve1;
    /// @notice earmarked tokens
    mapping(uint16 => uint256) public marked0;
    mapping(uint16 => uint256) public marked1;
    mapping(uint16 => PartialSync) public partialSyncs;
    mapping(uint16 => bytes) public trustedRemoteLookup;
    mapping(uint16 => bytes) public sgTrustedBridge;

    function addTrustedRemote(uint16 chainId, address remote, address local) external {
        require(msg.sender == IdAMMFactory(factory).admin(), "dAMM: FORBIDDEN");
        trustedRemoteLookup[chainId] = abi.encodePacked(remote, local);
    }

    function addStargateTrustedBridge(uint16 chainId, address remote, address local) external {
        require(msg.sender == IdAMMFactory(factory).admin(), "dAMM: FORBIDDEN");
        sgTrustedBridge[chainId] = abi.encodePacked(remote, local);
    }

    /*/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\
                            CONSTRUCTOR
    /|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\*/

    constructor(address _factory) ERC20("dAMM", "dAMM", 18) {
        factory = _factory;
    }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory);
        require(token0 == address(0) && token1 == address(0));
        token0 = _token0;
        token1 = _token1;
    }

    /*/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\
                            EXTERNAL FUNCTIONS
    /|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\*/

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

    /// @notice Callback used by Stargate when doing a cross-chain swap.
    /// @param _srcChainId The chainId of the remote chain.
    /// @param _srcAddress The address of the remote chain.
    /// @param _nonce nonce
    /// @param _token The token contract on the local chain.
    /// @param _bridgedAmount The quantity of local _token tokens.
    /// @param _payload Extra payload.
    function sgReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint256 _nonce,
        address _token,
        uint256 _bridgedAmount,
        bytes memory _payload
    ) external override {
        require(msg.sender == IdAMMFactory(factory).stargateRouter(), "NOT STARGATE");
        require(keccak256(_srcAddress) == keccak256(sgTrustedBridge[_srcChainId]), "NOT TRUSTED");
        (uint256 earmarkedAmount, uint256 exactBridgedAmount) = abi.decode(_payload, (uint256, uint256));
        // check if already partial sync
        // @note Maybe enforce check that second partial sync is "pair" of first one
        PartialSync memory partialSync = partialSyncs[_srcChainId];
        if (partialSync.token == address(0)) {
            partialSyncs[_srcChainId] = PartialSync(_token, exactBridgedAmount, earmarkedAmount);
        } else {
            // can proceed with full sync
            if (partialSync.token == token0) {
                _syncFromL2(
                    _srcChainId,
                    partialSync.bridgedAmount,
                    exactBridgedAmount,
                    partialSync.earmarkedAmount,
                    earmarkedAmount
                );
            } else {
                _syncFromL2(
                    _srcChainId,
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

    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload)
        external
        override
    {
        require(msg.sender == IdAMMFactory(factory).lzEndpoint());
        require(keccak256(_srcAddress) == keccak256(trustedRemoteLookup[_srcChainId]));
        uint256 messageType = abi.decode(_payload, (uint256));
        if (messageType == MessageType.BURN_VOUCHER) {
            // token address should be either L1 address of token0 or token1
            (, address token, address user, uint256 amount) = abi.decode(_payload, (uint256, address, address, uint256));
            _completeVoucherBurn(_srcChainId, token, user, amount);
        }
    }

    function syncL2(uint16 _destChainId, address _amm) external payable {
        bytes memory remoteAndLocalAddresses = abi.encodePacked(_amm, address(this));
        bytes memory payload = abi.encode(reserve0, reserve1);
        ILayerZeroEndpoint endpoint = ILayerZeroEndpoint(IdAMMFactory(factory).lzEndpoint());
        endpoint.send{value: msg.value}(
            _destChainId, // destination LayerZero chainId
            remoteAndLocalAddresses, // send to this address on the destination
            payload, // bytes payload
            payable(msg.sender), // refund address
            address(0x0), // future parameter
            bytes("") // adapterParams (see "Advanced Features")
        );
    }

    /*/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\
                            INTERNAL FUNCTIONS
    /|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\*/

    /// @notice Completes a voucher burn initiated on the L2.
    /// @dev Checks if user is able to burn or not should be done on L2 beforehand.
    /// @param srcChainId The chainId of the remote chain.
    /// @param token The token contract on the local chain.
    /// @param user The user who initiated the burn.
    /// @param amount The quantity of local _token tokens.
    function _completeVoucherBurn(uint16 srcChainId, address token, address user, uint256 amount) internal {
        require(token == token0 || token == token1, "BURN:INVALID TOKEN");
        // update earmarked tokens
        if (token == token0) {
            marked0[srcChainId] -= amount;
        } else {
            marked1[srcChainId] -= amount;
        }
        ERC20(token).transfer(user, amount);
    }

    /// @notice Syncing implies bridging the tokens from the L2 back to the L1.
    /// @notice These tokens are simply added back to the reserves.
    /// @dev    This should be an authenticated call, only callable by the operator.
    /// @dev    The sync should be followed by a sync on the L2.
    function _syncFromL2(uint16 source, uint256 bridged0, uint256 bridged1, uint256 earmarked0, uint256 earmarked1)
        internal
    {
        uint256 newreserve0 = reserve0 + bridged0 - (earmarked0 - marked0[source]);
        uint256 newreserve1 = reserve1 + bridged1 - (earmarked1 - marked1[source]);
        reserve0 = newreserve0;
        reserve1 = newreserve1;
        marked0[source] = earmarked0;
        marked1[source] = earmarked1;
        require(healthFactor() >= MINIMUM_HF, "SYNC:BELOW MINIMUM HF");
    }

    /*/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\
                            VIEW FUNCTIONS
    /|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\/|\*/

    function healthFactor() public view returns (uint256) {
        uint256 r0 = reserve0;
        uint256 r1 = reserve1;
        uint256 ts = totalSupply;
        uint256 decimals0 = ERC20(token0).decimals();
        uint256 decimals1 = ERC20(token1).decimals();
        if (decimals0 == 6 && decimals1 == 6) {
            r0 = r0 * 10 ** 12;
            r1 = r1 * 10 ** 12;
            ts = ts * 10 ** 12;
        } else if (decimals0 == 6 && decimals1 == 18) {
            r0 = r0 * 10 ** 12;
            ts = ts * 10 ** 6;
        } else if (decimals0 == 18 && decimals1 == 6) {
            r1 = r1 * 10 ** 12;
            ts = ts * 10 ** 6;
        }
        return FixedPointMathLib.divWadUp(
            FixedPointMathLib.sqrt(FixedPointMathLib.mulWadUp(reserve0, reserve1)), totalSupply
        );
    }
}
