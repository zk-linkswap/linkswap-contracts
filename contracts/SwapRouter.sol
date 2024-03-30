// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import {ISwapRouter02} from "./interfaces/router/ISwapRouter02.sol";
import {ISwapFactory} from "./interfaces/ISwapFactory.sol";
import {ISwapPair} from "./interfaces/ISwapPair.sol";
import {TransferHelper} from "./libraries/router/TransferHelper.sol";
import {SwapRouterLibrary} from "./libraries/router/SwapRouterLibrary.sol";
import {IWNativeToken} from "./interfaces/router/IWNativeToken.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {SafeMath} from "./libraries/SafeMath.sol";

contract SwapRouter is ISwapRouter02 {
    using SafeMath for uint256;

    address private immutable _factory;
    address private immutable _WNativeToken;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "SwapRouter: EXPIRED");
        _;
    }

    constructor(address factoryAddr, address wNativeTokenAddr) {
        _factory = factoryAddr;
        _WNativeToken = wNativeTokenAddr;
    }

    function factory() external view returns (address) {
        return _factory;
    }

    function WNativeToken() external view returns (address) {
        return _WNativeToken;
    }

    receive() external payable {
        assert(msg.sender == _WNativeToken); // only accept Native Token via fallback from the WNativeToken contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (ISwapFactory(_factory).getPair(tokenA, tokenB) == address(0)) {
            ISwapFactory(_factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = SwapRouterLibrary.getReserves(_factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = SwapRouterLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "SwapRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = SwapRouterLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "SwapRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = SwapRouterLibrary.pairFor(_factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = ISwapPair(pair).mint(to);
    }

    function addLiquidityNativeToken(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountNativeTokenMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountNativeToken, uint256 liquidity)
    {
        (amountToken, amountNativeToken) =
            _addLiquidity(token, _WNativeToken, amountTokenDesired, msg.value, amountTokenMin, amountNativeTokenMin);
        address pair = SwapRouterLibrary.pairFor(_factory, token, _WNativeToken);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWNativeToken(_WNativeToken).deposit{value: amountNativeToken}();
        assert(IWNativeToken(_WNativeToken).transfer(pair, amountNativeToken));
        liquidity = ISwapPair(pair).mint(to);
        // refund dust native token, if any
        if (msg.value > amountNativeToken) {
            TransferHelper.safeTransferNativeToken(msg.sender, msg.value - amountNativeToken);
        }
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = SwapRouterLibrary.pairFor(_factory, tokenA, tokenB);
        ISwapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = ISwapPair(pair).burn(to);
        (address token0,) = SwapRouterLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "SwapRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "SwapRouter: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityNativeToken(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeTokenMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountNativeToken) {
        (amountToken, amountNativeToken) = removeLiquidity(
            token, _WNativeToken, liquidity, amountTokenMin, amountNativeTokenMin, address(this), deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWNativeToken(_WNativeToken).withdraw(amountNativeToken);
        TransferHelper.safeTransferNativeToken(to, amountNativeToken);
    }

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
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = SwapRouterLibrary.pairFor(_factory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        ISwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityNativeTokenWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeTokenMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountToken, uint256 amountNativeToken) {
        address pair = SwapRouterLibrary.pairFor(_factory, token, _WNativeToken);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        ISwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountNativeToken) =
            removeLiquidityNativeToken(token, liquidity, amountTokenMin, amountNativeTokenMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****

    function removeLiquidityNativeTokenSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeTokenMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountNativeToken) {
        (, amountNativeToken) = removeLiquidity(
            token, _WNativeToken, liquidity, amountTokenMin, amountNativeTokenMin, address(this), deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWNativeToken(_WNativeToken).withdraw(amountNativeToken);
        TransferHelper.safeTransferNativeToken(to, amountNativeToken);
    }

    function removeLiquidityNativeTokenWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNativeTokenMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountNativeToken) {
        address pair = SwapRouterLibrary.pairFor(_factory, token, _WNativeToken);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        ISwapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountNativeToken = removeLiquidityNativeTokenSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountNativeTokenMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair

    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = SwapRouterLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOut) : (amountOut, uint256(0));
            address to = i < path.length - 2 ? SwapRouterLibrary.pairFor(_factory, output, path[i + 2]) : _to;
            ISwapPair(SwapRouterLibrary.pairFor(_factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = SwapRouterLibrary.getAmountsOut(_factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "SwapRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwapRouterLibrary.pairFor(_factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = SwapRouterLibrary.getAmountsIn(_factory, amountOut, path);
        require(amounts[0] <= amountInMax, "SwapRouter: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwapRouterLibrary.pairFor(_factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactNativeTokenForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == _WNativeToken, "SwapRouter: INVALID_PATH");
        amounts = SwapRouterLibrary.getAmountsOut(_factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "SwapRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWNativeToken(_WNativeToken).deposit{value: amounts[0]}();
        assert(IWNativeToken(_WNativeToken).transfer(SwapRouterLibrary.pairFor(_factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactNativeToken(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == _WNativeToken, "SwapRouter: INVALID_PATH");
        amounts = SwapRouterLibrary.getAmountsIn(_factory, amountOut, path);
        require(amounts[0] <= amountInMax, "SwapRouter: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwapRouterLibrary.pairFor(_factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWNativeToken(_WNativeToken).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferNativeToken(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForNativeToken(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == _WNativeToken, "SwapRouter: INVALID_PATH");
        amounts = SwapRouterLibrary.getAmountsOut(_factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "SwapRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwapRouterLibrary.pairFor(_factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWNativeToken(_WNativeToken).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferNativeToken(to, amounts[amounts.length - 1]);
    }

    function swapNativeTokenForExactTokens(uint256 amountOut, address[] calldata path, address to, uint256 deadline)
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        require(path[0] == _WNativeToken, "SwapRouter: INVALID_PATH");
        amounts = SwapRouterLibrary.getAmountsIn(_factory, amountOut, path);
        require(amounts[0] <= msg.value, "SwapRouter: EXCESSIVE_INPUT_AMOUNT");
        IWNativeToken(_WNativeToken).deposit{value: amounts[0]}();
        assert(IWNativeToken(_WNativeToken).transfer(SwapRouterLibrary.pairFor(_factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust native token, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferNativeToken(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = SwapRouterLibrary.sortTokens(input, output);
            ISwapPair pair = ISwapPair(SwapRouterLibrary.pairFor(_factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) =
                    input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
                amountOutput = SwapRouterLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint256 amount0Out, uint256 amount1Out) =
                input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? SwapRouterLibrary.pairFor(_factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwapRouterLibrary.pairFor(_factory, path[0], path[1]), amountIn
        );
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            "SwapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactNativeTokenForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == _WNativeToken, "SwapRouter: INVALID_PATH");
        uint256 amountIn = msg.value;
        IWNativeToken(_WNativeToken).deposit{value: amountIn}();
        assert(IWNativeToken(_WNativeToken).transfer(SwapRouterLibrary.pairFor(_factory, path[0], path[1]), amountIn));
        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            "SwapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForNativeTokenSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == _WNativeToken, "SwapRouter: INVALID_PATH");
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, SwapRouterLibrary.pairFor(_factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IERC20(_WNativeToken).balanceOf(address(this));
        require(amountOut >= amountOutMin, "SwapRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWNativeToken(_WNativeToken).withdraw(amountOut);

        TransferHelper.safeTransferNativeToken(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB)
        public
        pure
        virtual
        override
        returns (uint256 amountB)
    {
        return SwapRouterLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountOut)
    {
        return SwapRouterLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        virtual
        override
        returns (uint256 amountIn)
    {
        return SwapRouterLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return SwapRouterLibrary.getAmountsOut(_factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return SwapRouterLibrary.getAmountsIn(_factory, amountOut, path);
    }
}
