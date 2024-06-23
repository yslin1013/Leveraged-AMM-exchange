// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    uint8 public immutable DECIMALS;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _amount) ERC20(_name, _symbol) {
        DECIMALS = _decimals;
        _mint(msg.sender, _amount);
    }

    function decimals() public view override returns (uint8) {
        return DECIMALS;
    }
}
