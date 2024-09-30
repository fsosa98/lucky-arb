// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ERC20} from "@solmate/tokens/ERC20.sol";

contract ArbToken is ERC20 {
    uint256 constant INITIAL_SUPPLY = 1000000000000000000000000;
    uint8 constant DECIMALS = 18;

    constructor() ERC20("ArbToken", "ARB", DECIMALS) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function mint(address to, uint256 value) public {
        _mint(to, value);
    }
}
