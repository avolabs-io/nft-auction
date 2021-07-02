//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTAuction is IERC721Receiver {
    mapping(address => Auction) public nftContractAuctions;

    //Each Auction is unique to each NFT (contract + id pairing)
    struct Auction {
        //map token ID to
        IERC721 _nftContract;
        mapping(uint256 => uint256) minPrices;
        mapping(uint256 => uint256) auctionLengths;
        mapping(uint256 => uint256) auctionEnds;
        mapping(uint256 => uint256) nftHighestBids;
        mapping(uint256 => address) nftHighestBidders;
        mapping(uint256 => address) nftSellers;
    }

    modifier auctionOngoing(address _nftContractAddress, uint256 _tokenId) {
        require(
            isAuctionOngoing(_nftContractAddress, _tokenId),
            "Auction has ended"
        );
        _;
    }

    // constructor
    constructor() {
        console.log("Hello world");
    }

    function createNewNftAuction(
        address nftContractAddress,
        uint256 tokenId,
        uint256 minPrice,
        uint256 auctionLength
    ) public {
        // Sending our contract the NFT.
        require(minPrice > 0, "Minimum Price cannot be 0");
        IERC721 nftContract = IERC721(nftContractAddress);
        //Store the token id, token contract and minimum price
        nftContractAuctions[nftContractAddress]._nftContract = nftContract;
        nftContractAuctions[nftContractAddress].minPrices[tokenId] = minPrice;
        nftContractAuctions[nftContractAddress].auctionLengths[
            tokenId
        ] = auctionLength;
        nftContractAuctions[nftContractAddress].nftSellers[tokenId] = msg
        .sender;

        //transfer NFT to this smart contract
        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    // bid functions.
    //Add the functionality that holds the auction until first bid.
    // the auction time should then kick off
    //each new bid should add time to the auction length
    //each new bid should increase by a percentage
    function makeBid(address _nftContractAddress, uint256 _tokenId)
        public
        payable
        auctionOngoing(_nftContractAddress, _tokenId)
    {
        require(
            msg.sender !=
                nftContractAuctions[_nftContractAddress].nftSellers[_tokenId],
            "Owner cannot bid on own NFT"
        );
        require(
            msg.value >=
                nftContractAuctions[_nftContractAddress].minPrices[_tokenId],
            "Bid must be higher than minimum bid"
        );
        require(
            msg.value >=
                (nftContractAuctions[_nftContractAddress].nftHighestBids[
                    _tokenId
                ] * 110) /
                    100,
            "Bid must be 10% more than previous highest bid"
        );

        updateAuctionEnd(_nftContractAddress, _tokenId);

        //split up revert and update into two methods?

        revertPreviousBidAndUpdateHighestBid(_nftContractAddress, _tokenId);

        console.log(msg.value);
    }

    function updateAuctionEnd(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        if (isFirstBid(_nftContractAddress, _tokenId)) {
            nftContractAuctions[_nftContractAddress].auctionEnds[_tokenId] =
                nftContractAuctions[_nftContractAddress].auctionLengths[
                    _tokenId
                ] +
                block.timestamp;
        } else {
            nftContractAuctions[_nftContractAddress].auctionEnds[_tokenId] =
                nftContractAuctions[_nftContractAddress].auctionLengths[
                    _tokenId
                ] +
                nftContractAuctions[_nftContractAddress].auctionEnds[_tokenId];
        }
    }

    function revertPreviousBidAndUpdateHighestBid(
        address _nftContractAddress,
        uint256 _tokenId
    ) internal {
        if (!isFirstBid(_nftContractAddress, _tokenId)) {
            payable(
                nftContractAuctions[_nftContractAddress].nftHighestBidders[
                    _tokenId
                ]
            ).transfer(
                nftContractAuctions[_nftContractAddress].nftHighestBids[
                    _tokenId
                ]
            );
        }
        nftContractAuctions[_nftContractAddress].nftHighestBids[_tokenId] = msg
        .value;
        nftContractAuctions[_nftContractAddress].nftHighestBidders[
            _tokenId
        ] = msg.sender;
    }

    function settleAuction(address _nftContractAddress, uint256 _tokenId)
        public
    {
        require(
            !isAuctionOngoing(_nftContractAddress, _tokenId),
            "Auction is not yet over"
        );
        if (!isFirstBid(_nftContractAddress, _tokenId)) {
            //Send NFT to bidder and payout to seller
            nftContractAuctions[_nftContractAddress]
                ._nftContract
                .safeTransferFrom(
                address(this),
                nftContractAuctions[_nftContractAddress].nftHighestBidders[
                    _tokenId
                ],
                _tokenId
            );

            payable(
                nftContractAuctions[_nftContractAddress].nftSellers[_tokenId]
            ).transfer(
                nftContractAuctions[_nftContractAddress].nftHighestBids[
                    _tokenId
                ]
            );
        }
    }

    function isFirstBid(address _nftContractAddress, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        return
            !(nftContractAuctions[_nftContractAddress].nftHighestBids[
                _tokenId
            ] > 0);
    }

    function isAuctionOngoing(address _nftContractAddress, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        return (isFirstBid(_nftContractAddress, _tokenId) ||
            block.timestamp <
            nftContractAuctions[_nftContractAddress].auctionEnds[_tokenId]);
    }

    //ERC721Receiver function to ensure usage of ERC721 function safeTransferFrom
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
