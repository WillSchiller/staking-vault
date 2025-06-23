// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev a mock UDSC token for testing purposes
contract USDN is ERC20 {
    constructor() ERC20("USD N", "USDN") {
        _mint(msg.sender, 1_000_000_000 * 1e6);
    }

    function decimals() public view override returns (uint8) {
        return 6;
    }
}
