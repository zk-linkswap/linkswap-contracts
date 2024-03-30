// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract TestERC20Token is ERC20Burnable {
    /**
     * @dev Constructor to initialize the token with default values.
     * You can edit these values as needed.
     */
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        // Default initial supply of 1 billion tokens (with 18 decimals)
        uint256 initialSupply = 1_000_000_000 * (10 ** 18);

        // The initial supply is minted to the deployer's address
        _mint(msg.sender, initialSupply);
    }
}
