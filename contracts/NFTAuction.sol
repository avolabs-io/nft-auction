//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTAuction {
    uint256 public nftIndex;
    mapping(uint256 => IERC721) public nftContracts;
    mapping(uint256 => uint256) public tokenIds;
    mapping(uint256 => uint256) public minPrices;

    // constructor
    constructor() {
        console.log("Hello world");
    }

    function newNftAuction(
        address nftContractAddress,
        uint256 tokenId,
        uint256 minPrice
    ) public {
        // Sending our contract the NFT.
        require(minPrice >0, "Minimum Price cannot be 0");
        IERC721 nftContract = IERC721(nftContractAddress);
        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);

        nftIndex++;
        nftContracts[nftIndex] = nftContract;
        tokenIds[nftIndex] = tokenId;
        minPrices[nftIndex] = minPrice;
    }

    // bid functions.
    function createBid(uint256 _nftIndex) public payable {
        require(msg.value >= minPrices[_nftIndex]);
        console.log(msg.value);
    }
}
