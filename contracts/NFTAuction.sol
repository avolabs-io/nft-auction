//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract NFTAuction {
    uint256 public nftIndex;
    mapping(uint256 => IERC721) public nftContracts;
    mapping(uint256 => uint256) public tokenIds;
    mapping(uint256 => uint256) public minPrices;
    mapping(uint256 => uint256) public nftHighestBids;
    mapping(uint256 => address) public nftHighestBidders;

    // constructor
    constructor() {
        console.log("Hello world");
    }

    function createNewNftAuction(
        address nftContractAddress,
        uint256 tokenId,
        uint256 minPrice
    ) public {
        // Sending our contract the NFT.
        require(minPrice > 0, "Minimum Price cannot be 0");
        IERC721 nftContract = IERC721(nftContractAddress);
        //Store the token id, token contract and minimum price
        nftIndex++;
        nftContracts[nftIndex] = nftContract;
        tokenIds[nftIndex] = tokenId;
        minPrices[nftIndex] = minPrice;
        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    // bid functions.
    function makeBid(uint256 _nftIndex) public payable {
        require(
            msg.sender != nftContracts[_nftIndex].ownerOf(tokenIds[_nftIndex]),
            "Owner cannot bid on own NFT"
        );
        require(
            msg.value >= minPrices[_nftIndex],
            "Bid must be higher than minimum bid"
        );
        require(
            msg.value >= nftHighestBids[_nftIndex],
            "Bid must exceed highest bid"
        );

        updateHighestBidAndRevertPreviousBid(_nftIndex);

        console.log(msg.value);
    }

    function revertPreviousBidAndUpdateHighestBid(uint256 _nftIndex) internal {
        if (nftHighestBidders[_nftIndex] != address(0)) {
            payable(nftHighestBidders[_nftIndex]).transfer(
                nftHighestBids[_nftIndex]
            );
        }
        nftHighestBids[_nftIndex] = msg.value;
        nftHighestBidders[_nftIndex] = msg.sender;
    }
}
