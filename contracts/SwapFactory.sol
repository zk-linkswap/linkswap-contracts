// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;

import "./SwapERC20.sol";
import "./SwapPair.sol";
import "./interfaces/ISwapFactory.sol";
import "./interfaces/ISwapPair.sol";

contract SwapFactory is ISwapFactory {
    address public owner;
    address public feeReceipt;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    modifier onlyOwner() {
        require(msg.sender == owner, "SwapFactory: FORBIDDEN");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
        feeReceipt = _owner;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, "Swap: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Swap: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "Swap: PAIR_EXISTS"); // single check is sufficient
        bytes memory bytecode = type(SwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ISwapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeReceipt(address _feeReceipt) external onlyOwner {
        feeReceipt = _feeReceipt;
    }
}
