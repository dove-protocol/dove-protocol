// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import "../interfaces/ILayerZeroReceiver.sol";
import "../interfaces/ILayerZeroEndpoint.sol";
import "./interfaces/IStargateRouter.sol";
import {Voucher} from "./Voucher.sol";
import "../MessageType.sol";

contract AMM is ReentrancyGuard, ILayerZeroReceiver {
    ILayerZeroEndpoint public lzEndpoint;
    IStargateRouter public stargateRouter;
    address public L1Target;

    ///@notice The bridged token0.
    ERC20 public token0;
    ///@notice The address of the native L1 token0.
    address public L1Token0;
    Voucher public voucher0;

    ///@notice The bridged token1.
    ERC20 public token1;
    ///@notice The address of the native L1 token1.
    address public L1Token1;
    Voucher public voucher1;

    uint256 public reserve0; // initially should be set with the L1 data
    uint256 public reserve1; // initially should be set with the L1 data
    uint256 public balance0;
    uint256 public balance1;
    /// @notice total accumumated fees (LPs+protocol).
    uint256 public fees0;
    uint256 public fees1;

    uint16 public destChainId;

    bytes32 public trustedRemoteHash;

    constructor(
        address _token0,
        address _L1Token0,
        address _token1,
        address _L1Token1,
        address _lzEndpoint,
        address _stargateRouter,
        address _L1Target,
        uint16 _destChainId
    ) {
        destChainId = _destChainId;
        lzEndpoint = ILayerZeroEndpoint(_lzEndpoint);
        stargateRouter = IStargateRouter(_stargateRouter);
        L1Target = _L1Target;

        token0 = ERC20(_token0);
        L1Token0 = _L1Token0;
        token1 = ERC20(_token1);
        L1Token1 = _L1Token1;

        /// @dev Assume one AMM per L2.
        voucher0 =
            new Voucher(string.concat("v", token0.name()), string.concat("v", token0.symbol()), token0.decimals());
        voucher1 =
            new Voucher(string.concat("v", token1.name()), string.concat("v", token1.symbol()), token1.decimals());

        trustedRemoteHash = keccak256(abi.encodePacked(_L1Target, address(this)));
    }

    /// @notice Swaps token 0/1 for token 1/0.
    /// @param amount0In The amount of token 0 to swap.
    /// @param amount1In The amount of token 1 to swap.
    /// @return amountOut The amount of the token we swap out.
    function swap(uint256 amount0In, uint256 amount1In) external nonReentrant returns (uint256 amountOut) {
        require(amount0In > 0 || amount1In > 0, "Amounts are 0");
        (ERC20 tokenIn, Voucher voucherOut, uint256 amountIn, uint256 reserveIn, uint256 reserveOut) = amount0In > 0
            ? (token0, voucher1, amount0In, reserve0, reserve1)
            : (token1, voucher0, amount1In, reserve1, reserve0);
        tokenIn.transferFrom(msg.sender, address(this), amountIn);
        uint256 fees = amountIn / 100; // 1%
        amountIn -= fees;
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);

        // update reserves
        if (amount0In > 0) {
            fees0 += fees;
            balance0 += amountIn;
            reserve0 += amount0In;
            reserve1 -= amountOut;
        } else {
            fees1 += fees;
            reserve0 -= amountOut;
            reserve1 += amount1In;
            balance1 += amountIn;
        }
        voucherOut.mint(msg.sender, amountOut);
    }

    /// @notice Syncs to the L1.
    /// @dev Dependent on SG.
    /// @param srcPoolId0 The id of the src pool for token0.
    /// @param dstPoolId0 The id of the dst pool for token0.
    /// @param srcPoolId1 The id of the src pool for token1.
    /// @param dstPoolId1 The id of the dst pool for token1.
    function syncToL1(uint256 srcPoolId0, uint256 dstPoolId0, uint256 srcPoolId1, uint256 dstPoolId1)
        external
        payable
    {
        // swap token0
        bytes memory payload = abi.encode(voucher0.totalSupply(), balance0);
        token0.approve(address(stargateRouter), balance0 + fees0);
        stargateRouter.swap{value: msg.value / 2}(
            destChainId,
            srcPoolId0,
            dstPoolId0,
            payable(msg.sender),
            balance0 + fees0,
            0,
            IStargateRouter.lzTxObj(10 ** 6, 0, "0x"),
            abi.encodePacked(L1Target),
            payload
        );
        fees0 = 0;
        balance0 = 0;
        // swap token1
        payload = abi.encode(voucher1.totalSupply(), balance1);
        token1.approve(address(stargateRouter), balance1 + fees1);
        stargateRouter.swap{value: msg.value / 2}(
            destChainId,
            srcPoolId1,
            dstPoolId1,
            payable(msg.sender),
            balance1 + fees1,
            0,
            IStargateRouter.lzTxObj(10 ** 6, 0, "0x"),
            abi.encodePacked(L1Target),
            payload
        );
        fees1 = 0;
        balance1 = 0;
    }

    /// @notice Allows user to burn his L2 vouchers to get the L1 tokens.
    /// @param amount0 The amount of voucher0 to burn.
    /// @param amount1 The amount of voucher1 to burn.
    function burnVouchers(uint256 amount0, uint256 amount1) external payable nonReentrant {
        uint256 fee = amount0 > 0 && amount1 > 0 ? msg.value / 2 : msg.value;
        // tell L1 that vouchers been burned
        bytes memory remoteAndLocalAddresses = abi.encodePacked(L1Target, address(this));
        if (amount0 > 0) {
            voucher0.burn(msg.sender, amount0);
            bytes memory payload = abi.encode(MessageType.BURN_VOUCHER, L1Token0, msg.sender, amount0);
            lzEndpoint.send{value: fee}(
                destChainId, // destination LayerZero chainId
                remoteAndLocalAddresses, // send to this address on the destination
                payload, // bytes payload
                payable(msg.sender), // refund address
                address(0x0), // future parameter
                bytes("") // adapterParams (see "Advanced Features")
            );
        }
        if (amount1 > 0) {
            voucher1.burn(msg.sender, amount1);
            bytes memory payload = abi.encode(MessageType.BURN_VOUCHER, L1Token1, msg.sender, amount1);
            lzEndpoint.send{value: fee}(
                destChainId, remoteAndLocalAddresses, payload, payable(msg.sender), address(0x0), bytes("")
            );
        }
    }

    function lzReceive(uint16 _srcChainId, bytes calldata _srcAddress, uint64 _nonce, bytes calldata _payload)
        external
        override
    {
        require(msg.sender == address(lzEndpoint), "LZENDPOINT ONLY");
        require(keccak256(_srcAddress) == trustedRemoteHash, "NOT TRUSTED");
        (reserve0, reserve1) = abi.decode(_payload, (uint256, uint256));
    }
}
