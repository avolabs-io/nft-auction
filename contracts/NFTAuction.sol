//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NFTAuction is IERC721Receiver {
    mapping(address => mapping(uint256 => Auction)) public nftContractAuctions;

    //Each Auction is unique to each NFT (contract + id pairing)
    struct Auction {
        //map token ID to
        IERC721 _nftContract;
        uint256 minPrice;
        uint256 auctionLength;
        uint256 auctionEnd;
        uint256 nftHighestBid;
        address nftHighestBidder;
        address nftSeller;
    }

    modifier auctionOngoing(address _nftContractAddress, uint256 _tokenId) {
        require(
            _isAuctionOngoing(_nftContractAddress, _tokenId),
            "Auction has ended"
        );
        _;
    }

    // constructor
    constructor() {}

    function _isMinimumBidMade(address _nftContractAddress, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        return (nftContractAuctions[_nftContractAddress][_tokenId]
        .nftHighestBid > 0);
    }

    function _isAuctionOngoing(address _nftContractAddress, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        return (nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd ==
            0 ||
            block.timestamp <
            nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd);
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
        nftContractAuctions[nftContractAddress][tokenId]
        ._nftContract = nftContract;
        nftContractAuctions[nftContractAddress][tokenId].minPrice = minPrice;
        nftContractAuctions[nftContractAddress][tokenId]
        .auctionLength = auctionLength;
        nftContractAuctions[nftContractAddress][tokenId].nftSeller = msg.sender;

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
                nftContractAuctions[_nftContractAddress][_tokenId].nftSeller,
            "Owner cannot bid on own NFT"
        );
        require(
            msg.value >=
                nftContractAuctions[_nftContractAddress][_tokenId].minPrice,
            "Bid must be higher than minimum bid"
        );
        require(
            msg.value >=
                (nftContractAuctions[_nftContractAddress][_tokenId]
                .nftHighestBid * 110) /
                    100,
            "Bid must be 10% more than previous highest bid"
        );

        _updateAuctionEnd(_nftContractAddress, _tokenId);

        //split up revert and update into two methods?

        _revertPreviousBidAndUpdateHighestBid(_nftContractAddress, _tokenId);
    }

    function _updateAuctionEnd(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        if (_isMinimumBidMade(_nftContractAddress, _tokenId)) {
            nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd =
                nftContractAuctions[_nftContractAddress][_tokenId]
                .auctionLength +
                block.timestamp;
        } else {
            nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd =
                nftContractAuctions[_nftContractAddress][_tokenId]
                .auctionLength +
                nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd;
        }
    }

    function _revertPreviousBidAndUpdateHighestBid(
        address _nftContractAddress,
        uint256 _tokenId
    ) internal {
        if (_isMinimumBidMade(_nftContractAddress, _tokenId)) {
            payable(
                nftContractAuctions[_nftContractAddress][_tokenId]
                    .nftHighestBidder
            ).transfer(
                nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid
            );
        }
        nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid = msg
        .value;
        nftContractAuctions[_nftContractAddress][_tokenId]
        .nftHighestBidder = msg.sender;
    }

    function settleAuction(address _nftContractAddress, uint256 _tokenId)
        public
    {
        require(
            !_isAuctionOngoing(_nftContractAddress, _tokenId),
            "Auction is not yet over"
        );
        if (_isMinimumBidMade(_nftContractAddress, _tokenId)) {
            //Send NFT to bidder and payout to seller
            nftContractAuctions[_nftContractAddress][_tokenId]
                ._nftContract
                .safeTransferFrom(
                address(this),
                nftContractAuctions[_nftContractAddress][_tokenId]
                    .nftHighestBidder,
                _tokenId
            );

            payable(
                nftContractAuctions[_nftContractAddress][_tokenId].nftSeller
            ).transfer(
                nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid
            );
        }
        //transfer NFT back to original seller if no bids made
        else {
            nftContractAuctions[_nftContractAddress][_tokenId]
                ._nftContract
                .safeTransferFrom(
                address(this),
                nftContractAuctions[_nftContractAddress][_tokenId].nftSeller,
                _tokenId
            );
        }
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
