// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20.sol";

contract HPC is ERC20 {
    constructor() ERC20("HPC", "HPC") {
        _mint(msg.sender, 210000000 * 10**decimals());
    }

    
}
