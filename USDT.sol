// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract USDT is ERC20, Ownable {
    constructor() ERC20("USDT", "USDT") Ownable(msg.sender) {}

    function mint(address _address) public {
        _mint(_address, 225000000 * 10**18);
    }
}
