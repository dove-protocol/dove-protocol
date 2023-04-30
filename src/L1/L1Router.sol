// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity >=0.8.15;

import {ERC20} from "solmate/tokens/ERC20.sol";

import "./interfaces/IL1Router.sol";
import "./interfaces/IL1Factory.sol";
import "./interfaces/IDove.sol";

library Math {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

contract L1Router is IL1Router {
    /// @notice factory address
    address public immutable factory;
    /// @notice minimum liquidity able to be added through L1router.addLiquidity()
    uint256 internal constant MINIMUM_LIQUIDITY = 10 ** 3;
    /// @notice pair code hash
    bytes32 immutable pairCodeHash;

    /*###############################################################
                            CONSTRUCTOR
    ###############################################################*/

    /// @notice constructor
    /// @param _factory factory address
    constructor(address _factory) {
        factory = _factory;
        pairCodeHash = IL1Factory(_factory).pairCodeHash();
    }

    /*###############################################################
                            ROUTER
    ###############################################################*/

    /// @notice sort tokens for pair creation
    /// @param tokenA tokenA address
    /// @param tokenB tokenB address
    function sortTokens(address tokenA, address tokenB) public pure override returns (address token0, address token1) {
        // revert if addresses are identical
        if (tokenA == tokenB) revert IdenticalAddress();
        // order tokens
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // revert if token0 is zero address
        if (token0 == address(0)) revert ZeroAddress();
    }

    /// @notice calculates the CREATE2 address for a pair without making any external calls
    /// @param tokenA tokenA address
    /// @param tokenB tokenB address
    function pairFor(address tokenA, address tokenB) public view override returns (address pair) {
        // sort tokens
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        // compute address
        pair = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex"ff",
                            factory,
                            keccak256(abi.encodePacked(token0, token1, true)),
                            pairCodeHash // init code hash
                        )
                    )
                )
            )
        );
    }

    /// @notice given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    /// @param amountA amount of reserveA tokens
    /// @param reserveA reserveA amount
    /// @param reserveB reserveB amount
    /// @dev used by internal _addLiquidity() and external quoteAddLiquity()
    function _quoteLiquidity(uint256 amountA, uint256 reserveA, uint256 reserveB)
        internal
        pure
        returns (uint256 amountB)
    {
        // revert if amount is not > 0
        if (!(amountA > 0)) revert InsuffcientAmountForQuote();
        // revert if reserveA and reserveB is not > 0
        if (!(reserveA > 0 && reserveB > 0)) revert InsufficientLiquidity();
        // calculate amountB for quote
        amountB = amountA * reserveB / reserveA;
    }

    /// @notice fetches and sorts the reserves for a pair
    /// @param tokenA tokenA address
    /// @param tokenB tokenB address
    function getReserves(address tokenA, address tokenB)
        public
        view
        override
        returns (uint256 reserveA, uint256 reserveB)
    {
        // sort tokens
        (address token0,) = sortTokens(tokenA, tokenB);
        // get reserves
        (uint256 reserve0, uint256 reserve1) = IDove(IL1Factory(factory).getPair(tokenA, tokenB)).getReserves();
        // order reserves then return them
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /// @notice check if "pair" is a pair
    /// @param pair pair address
    function isPair(address pair) external view override returns (bool) {
        return IL1Factory(factory).isPair(pair);
    }

    /// @notice quote adding liquidity to a pair
    /// @param tokenA tokenA address
    /// @param tokenB tokenB address
    /// @param amountADesired amount of tokenA desired
    /// @param amountBDesired amount of tokenB desired
    function quoteAddLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired)
        external
        view
        override
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        // create the pair if it doesn't exist yet
        address _pair = IL1Factory(factory).getPair(tokenA, tokenB);
        (uint256 reserveA, uint256 reserveB) = (0, 0);
        uint256 _totalSupply = 0;
        // check if pair address is not zero address, meaning it exists
        if (_pair != address(0)) {
            _totalSupply = ERC20(_pair).totalSupply();
            (reserveA, reserveB) = getReserves(tokenA, tokenB);
        }
        // check reserve amounts are 0
        if (reserveA == 0 && reserveB == 0) {
            // add initial liquidity
            (amountA, amountB) = (amountADesired, amountBDesired);
            liquidity = Math.sqrt(amountA * amountB) - MINIMUM_LIQUIDITY;
        } else {
            // calculate amounts using _quoteLiquidity(), then return token amounts and liquidity
            uint256 amountBOptimal = _quoteLiquidity(amountADesired, reserveA, reserveB);
            // if amountBOptimal <= amountBDesired, use optimal
            if (amountBOptimal <= amountBDesired) {
                (amountA, amountB) = (amountADesired, amountBOptimal);
                liquidity = Math.min(amountA * _totalSupply / reserveA, amountB * _totalSupply / reserveB);
            } else { // use amountBDesired
                uint256 amountAOptimal = _quoteLiquidity(amountBDesired, reserveB, reserveA);
                (amountA, amountB) = (amountAOptimal, amountBDesired);
                liquidity = Math.min(amountA * _totalSupply / reserveA, amountB * _totalSupply / reserveB);
            }
        }
    }

    /// @notice quote removing liquidity from a pair
    /// @param tokenA tokenA address
    /// @param tokenB tokenB address
    /// @param liquidity liquidity amount
    function quoteRemoveLiquidity(address tokenA, address tokenB, uint256 liquidity)
        external
        view
        override
        returns (uint256 amountA, uint256 amountB)
    {
        // create the pair if it doesn't exist yet
        address _pair = IL1Factory(factory).getPair(tokenA, tokenB);
        // check pair is zero adderss, if so return 0 tokens
        if (_pair == address(0)) {
            return (0, 0);
        }
        (uint256 reserveA, uint256 reserveB) = getReserves(tokenA, tokenB);
        uint256 _totalSupply = ERC20(_pair).totalSupply();
        // calculate amount to remove from pool and give to user
        amountA = liquidity * reserveA / _totalSupply; // using balances ensures pro-rata distribution
        amountB = liquidity * reserveB / _totalSupply; // using balances ensures pro-rata distribution
    }

    /// @notice add liquidity to a pair
    /// @param tokenA tokenA address
    /// @param tokenB tokenB address
    /// @param amountADesired amount of tokenA desired
    /// @param amountBDesired amount of tokenB desired
    /// @param amountAMin minimum amount of tokenA
    /// @param amountBMin minimum amount of tokenB
    /// @dev used by external addLiquidity()
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        // revert if less than minimum liquidity
        if (!(amountADesired >= amountAMin && amountBDesired >= amountBMin)) revert BelowMinimumAmount();
        // create the pair if it doesn't exist yet
        address _pair = IL1Factory(factory).getPair(tokenA, tokenB);
        if (_pair == address(0)) revert PairDoesNotExist();
        // get reserves
        (uint256 reserveA, uint256 reserveB) = getReserves(tokenA, tokenB);
        // if reserves are 0, add initial liquidity
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else { // use _quoteLiquidity() to calculate amounts, if quoted amount is below amountMin, revert
            uint256 amountBOptimal = _quoteLiquidity(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin) revert InsufficientAmountB();
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = _quoteLiquidity(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                if (amountBOptimal < amountBMin) revert InsufficientAmountA();
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    /// @notice add liquidity to a dove pair
    /// @param tokenA tokenA address
    /// @param tokenB tokenB address
    /// @param amountADesired amount of tokenA desired
    /// @param amountBDesired amount of tokenB desired
    /// @param amountAMin minimum amount of tokenA
    /// @param amountBMin minimum amount of tokenB
    /// @param to address to send LP tokens to
    /// @param deadline deadline timestamp to add liquidity by
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external override returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // check deadline, if passed, revert
        if (deadline < block.timestamp) revert Expired();
        // get amounts that can be added to the pair
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = IL1Factory(factory).getPair(tokenA, tokenB);
        // transfer tokens from LP provider/"to" to pair
        _safeTransferFrom(tokenA, msg.sender, pair, amountA);
        _safeTransferFrom(tokenB, msg.sender, pair, amountB);
        // mint LP tokens to "to"
        liquidity = IDove(pair).mint(to);
    }

    /// @notice remove liquidity from a dove pair
    /// @param tokenA tokenA address
    /// @param tokenB tokenB address
    /// @param liquidity liquidity amount
    /// @param amountAMin minimum amount of tokenA
    /// @param amountBMin minimum amount of tokenB
    /// @param to address to send tokens to
    /// @param deadline deadline timestamp to remove liquidity by
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public override returns (uint256 amountA, uint256 amountB) {
        // check deadline, if passed, revert
        if (deadline < block.timestamp) revert Expired();
        address pair = IL1Factory(factory).getPair(tokenA, tokenB);
        // transfer LP tokens to pair, if failed, revert
        if (!(ERC20(pair).transferFrom(msg.sender, pair, liquidity))) revert TransferLiqToPairFailed();
        // burn LP tokens from pair
        (uint256 amount0, uint256 amount1) = IDove(pair).burn(to);
        // sort tokens
        (address token0,) = sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        // revert if less than minimum amount quoted in function input
        if (amountA < amountAMin) revert InsufficientAmountA();
        if (amountB < amountBMin) revert InsufficientAmountB();
    }

    /// @notice remove liquidity from a dove pair with permit
    /// @param tokenA tokenA address
    /// @param tokenB tokenB address
    /// @param liquidity liquidity amount
    /// @param amountAMin minimum amount of tokenA
    /// @param amountBMin minimum amount of tokenB
    /// @param to address to send tokens to
    /// @param deadline deadline timestamp to remove liquidity by
    /// @param approveMax approve maximum amount of LP tokens
    /// @param v signature
    /// @param r signature
    /// @param s signature
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override returns (uint256 amountA, uint256 amountB) {
        address pair = IL1Factory(factory).getPair(tokenA, tokenB);
        {
            // get approval value
            uint256 value = approveMax ? type(uint256).max : liquidity;
            ERC20(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        }
        // remove liquidity
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    /// @notice transfer "value" of "token", to "to" address
    /// @param token token address
    /// @param to address to send tokens to
    /// @param value amount of tokens to send
    function _safeTransfer(address token, address to, uint256 value) internal {
        if (!(token.code.length > 0)) revert CodeLength();
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(ERC20.transfer.selector, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert TransferFailed();
    }

    /// @notice transfer "value" of "token", from "from" address to "to" address
    /// @param token token address
    /// @param from address to send tokens from
    /// @param to address to send tokens to
    /// @param value amount of tokens to send
    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        if (!(token.code.length > 0)) revert CodeLength();
        (bool success, bytes memory data) =
            token.call(abi.encodeWithSelector(ERC20.transferFrom.selector, from, to, value));
        if (!(success && (data.length == 0 || abi.decode(data, (bool))))) revert TransferFailed();
    }
}
