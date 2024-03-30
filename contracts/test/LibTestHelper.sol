// SPDX-License-Identifier: GPL-3.0-or-later

import {SwapRouterLibrary} from "../libraries/router/SwapRouterLibrary.sol";
import {SwapPair} from "../SwapPair.sol";

pragma solidity ^0.8.20;

contract LibTestHelper {
    function getChainId() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    // zksync byte code hash is so different and hacky
    // so we don't dive too deep into calculating it
    // some code hash sample: https://github.com/matter-labs/era-system-contracts/blob/d42f707cbe6938a76fa29f4bf76203af1e13f51f/contracts/libraries/Utils.sol#L82
    function pairFor(address factory, address tokenA, address tokenB) external view returns (address pair) {
        pair = SwapRouterLibrary.pairFor(factory, tokenA, tokenB);
    }
}
