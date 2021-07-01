//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721MockContract is ERC721 {
    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
