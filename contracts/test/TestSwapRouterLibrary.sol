// SPDX-License-Identifier: GPL-3.0-or-later

import {SafeMath} from "../libraries/SafeMath.sol";
import {SwapPair} from "../SwapPair.sol";
import {ISwapPair} from "../interfaces/ISwapPair.sol";
import {SwapRouterLibrary} from "../libraries/router/SwapRouterLibrary.sol";

pragma solidity ^0.8.20;

contract TestSwapRouterLibrary {
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        (token0, token1) = SwapRouterLibrary.sortTokens(tokenA, tokenB);
    }

    // reading from factory is not the ideal way right now, zksync stack create2 is not fully evm compatible
    // this method can be tuned later
    function pairFor(address factory, address tokenA, address tokenB) internal view returns (address pair) {
        pair = SwapRouterLibrary.pairFor(factory, tokenA, tokenB);
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (reserveA, reserveB) = SwapRouterLibrary.getReserves(factory, tokenA, tokenB);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    // this method is not considering the fee
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        amountB = SwapRouterLibrary.quote(amountA, reserveA, reserveB);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOutWithFee(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 swapFeeRate)
        external
        pure
        returns (uint256 amountOut)
    {
        amountOut = SwapRouterLibrary.getAmountOutWithFee(amountIn, reserveIn, reserveOut, swapFeeRate);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountOut)
    {
        amountOut = SwapRouterLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 amountIn)
    {
        amountIn = SwapRouterLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountInWithFee(uint256 amountOut, uint256 reserveIn, uint256 reserveOut, uint256 swapFeeRate)
        external
        pure
        returns (uint256 amountIn)
    {
        amountIn = SwapRouterLibrary.getAmountInWithFee(amountOut, reserveIn, reserveOut, swapFeeRate);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint256 amountIn, address[] memory path)
        external
        view
        returns (uint256[] memory amounts)
    {
        amounts = SwapRouterLibrary.getAmountsOut(factory, amountIn, path);
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint256 amountOut, address[] memory path)
        external
        view
        returns (uint256[] memory amounts)
    {
        amounts = SwapRouterLibrary.getAmountsIn(factory, amountOut, path);
    }
}
