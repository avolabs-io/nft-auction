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
        uint256 auctionBidPeriod; //Length of time the auction is open in which a new bid can be made
        uint256 auctionEnd;
        uint256 nftHighestBid;
        uint256 bidIncreasePercentage;
        address nftHighestBidder;
        address nftSeller;
        address whiteListedBuyer;
    }
    uint256 public defaultBidIncreasePercentage;
    uint256 public defaultAuctionBidPeriod;
    uint256 public minimumSettableIncreasePercentage;

    modifier auctionOngoing(address _nftContractAddress, uint256 _tokenId) {
        require(
            _isAuctionOngoing(_nftContractAddress, _tokenId),
            "Auction has ended"
        );
        _;
    }

    modifier auctionMinPriceGreaterThanZero(uint256 _minPrice) {
        require(_minPrice > 0, "Minimum price cannot be 0");
        _;
    }

    modifier notNftSeller(address _nftContractAddress, uint256 _tokenId) {
        require(
            msg.sender !=
                nftContractAuctions[_nftContractAddress][_tokenId].nftSeller,
            "Owner cannot bid on own NFT"
        );
        _;
    }

    modifier bidExceedsMinPrice(address _nftContractAddress, uint256 _tokenId) {
        require(
            msg.value >=
                nftContractAuctions[_nftContractAddress][_tokenId].minPrice,
            "Bid must be higher than minimum bid"
        );
        _;
    }
    modifier bidPriceMeetsBidRequirements(
        address _nftContractAddress,
        uint256 _tokenId
    ) {
        require(
            msg.value >=
                (nftContractAuctions[_nftContractAddress][_tokenId]
                .nftHighestBid *
                    (100 +
                        _getBidIncreasePercentage(
                            _nftContractAddress,
                            _tokenId
                        ))) /
                    100,
            "Bid must be % more than previous highest bid"
        );
        _;
    }

    modifier onlyWhitelistedBuyer(
        address _nftContractAddress,
        uint256 _tokenId
    ) {
        require(
            nftContractAuctions[_nftContractAddress][_tokenId]
            .whiteListedBuyer == msg.sender,
            "only the whitelisted buyer can bid on this NFT"
        );
        _;
    }

    modifier minimumBidNotMade(address _nftContractAddress, uint256 _tokenId) {
        require(
            !_isMinimumBidMade(_nftContractAddress, _tokenId),
            "The auction has a valid bid made"
        );
        _;
    }

    // constructor
    constructor() {
        defaultBidIncreasePercentage = 10;
        defaultAuctionBidPeriod = 86400; //1 day
        minimumSettableIncreasePercentage = 5;
    }

    function _isMinimumBidMade(address _nftContractAddress, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        return
            nftContractAuctions[_nftContractAddress][_tokenId].minPrice > 0 &&
            (nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid >=
                nftContractAuctions[_nftContractAddress][_tokenId].minPrice);
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

    function _getBidIncreasePercentage(
        address _nftContractAddress,
        uint256 _tokenId
    ) internal view returns (uint256) {
        if (
            nftContractAuctions[_nftContractAddress][_tokenId]
            .bidIncreasePercentage == 0
        ) {
            return defaultBidIncreasePercentage;
        } else {
            return
                nftContractAuctions[_nftContractAddress][_tokenId]
                    .bidIncreasePercentage;
        }
    }

    function _getAuctionBidPeriod(address _nftContractAddress, uint256 _tokenId)
        internal
        view
        returns (uint256)
    {
        if (
            nftContractAuctions[_nftContractAddress][_tokenId]
            .auctionBidPeriod == 0
        ) {
            return defaultAuctionBidPeriod;
        } else {
            return
                nftContractAuctions[_nftContractAddress][_tokenId]
                    .auctionBidPeriod;
        }
    }

    function _createNewNftAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _minPrice
    ) internal auctionMinPriceGreaterThanZero(_minPrice) {
        // Sending our contract the NFT
        IERC721 nftContract = IERC721(_nftContractAddress);
        nftContract.safeTransferFrom(msg.sender, address(this), _tokenId);

        //Store the token id, token contract and minimum price
        nftContractAuctions[_nftContractAddress][_tokenId]
        ._nftContract = nftContract;
        nftContractAuctions[_nftContractAddress][_tokenId].minPrice = _minPrice;
        nftContractAuctions[_nftContractAddress][_tokenId].nftSeller = msg
        .sender;
        if (_isMinimumBidMade(_nftContractAddress, _tokenId)) {
            _updateAuctionEnd(_nftContractAddress, _tokenId);
        }
    }

    function createDefaultNftAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _minPrice
    ) external {
        _createNewNftAuction(_nftContractAddress, _tokenId, _minPrice);
    }

    function createNewNftAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _minPrice,
        uint256 _auctionBidPeriod, //this is the time that the auction lasts until another bid occurs
        uint256 _bidIncreasePercentage
    ) external {
        require(
            _bidIncreasePercentage >= minimumSettableIncreasePercentage,
            "Bid increase percentage must be greater than minimum increase percentage"
        );
        _createNewNftAuction(_nftContractAddress, _tokenId, _minPrice);

        nftContractAuctions[_nftContractAddress][_tokenId]
        .auctionBidPeriod = _auctionBidPeriod;
        nftContractAuctions[_nftContractAddress][_tokenId]
        .bidIncreasePercentage = _bidIncreasePercentage;
    }

    function createWhiteListSale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _minPrice,
        address _whiteListedBuyer
    ) external {
        _createNewNftAuction(_nftContractAddress, _tokenId, _minPrice);
        nftContractAuctions[_nftContractAddress][_tokenId]
        .whiteListedBuyer = _whiteListedBuyer;
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
        notNftSeller(_nftContractAddress, _tokenId)
        bidPriceMeetsBidRequirements(_nftContractAddress, _tokenId)
    {
        if (
            nftContractAuctions[_nftContractAddress][_tokenId]
            .whiteListedBuyer != address(0)
        ) {
            _concludeWhitelistSale(_nftContractAddress, _tokenId);
        } else {
            _updateOngoingAuction(_nftContractAddress, _tokenId);
        }
    }

    function _updateOngoingAuction(
        address _nftContractAddress,
        uint256 _tokenId
    ) internal {
        _reversePreviousBidAndUpdateHighestBid(_nftContractAddress, _tokenId);
        //min price not set, nft not up for auction yet
        if (nftContractAuctions[_nftContractAddress][_tokenId].minPrice != 0) {
            _updateAuctionEnd(_nftContractAddress, _tokenId);
        }
    }

    function _updateAuctionEnd(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        if (
            nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd == 0
        ) {
            nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd =
                _getAuctionBidPeriod(_nftContractAddress, _tokenId) +
                block.timestamp;
        } else {
            nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd =
                _getAuctionBidPeriod(_nftContractAddress, _tokenId) +
                nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd;
        }
    }

    function _resetAuction(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        nftContractAuctions[_nftContractAddress][_tokenId].minPrice = 0;
        nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd = 0;
        nftContractAuctions[_nftContractAddress][_tokenId].auctionBidPeriod = 0;
        nftContractAuctions[_nftContractAddress][_tokenId]
        .bidIncreasePercentage = 0;
        nftContractAuctions[_nftContractAddress][_tokenId]
        .whiteListedBuyer = address(0);
    }

    function _resetBids(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        nftContractAuctions[_nftContractAddress][_tokenId]
        .nftHighestBidder = address(0);
        nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid = 0;
    }

    function _updateHighestBid(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid = msg
        .value;
        nftContractAuctions[_nftContractAddress][_tokenId]
        .nftHighestBidder = msg.sender;
    }

    function _reversePreviousBid(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        payable(
            nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBidder
        ).transfer(
            nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid
        );
    }

    function _reversePreviousBidAndUpdateHighestBid(
        address _nftContractAddress,
        uint256 _tokenId
    ) internal {
        if (
            nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid > 0
        ) {
            _reversePreviousBid(_nftContractAddress, _tokenId);
        }

        _updateHighestBid(_nftContractAddress, _tokenId);
    }

    function _concludeWhitelistSale(
        address _nftContractAddress,
        uint256 _tokenId
    )
        internal
        onlyWhitelistedBuyer(_nftContractAddress, _tokenId)
        bidExceedsMinPrice(_nftContractAddress, _tokenId)
    {
        _updateHighestBid(_nftContractAddress, _tokenId); //no previous bid made
        _transferNftAndPaySeller(_nftContractAddress, _tokenId);
    }

    function _transferNftAndPaySeller(
        address _nftContractAddress,
        uint256 _tokenId
    ) internal {
        nftContractAuctions[_nftContractAddress][_tokenId]
            ._nftContract
            .safeTransferFrom(
            address(this),
            nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBidder,
            _tokenId
        );

        payable(nftContractAuctions[_nftContractAddress][_tokenId].nftSeller)
            .transfer(
            nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid
        );

        _resetAuction(_nftContractAddress, _tokenId);
        _resetBids(_nftContractAddress, _tokenId);
    }

    function settleAuction(address _nftContractAddress, uint256 _tokenId)
        external
    {
        require(
            !_isAuctionOngoing(_nftContractAddress, _tokenId),
            "Auction is not yet over"
        );
        if (_isMinimumBidMade(_nftContractAddress, _tokenId)) {
            //Send NFT to bidder and payout to seller
            _transferNftAndPaySeller(_nftContractAddress, _tokenId);
        }
    }

    function withdrawNft(address _nftContractAddress, uint256 _tokenId)
        external
        minimumBidNotMade(_nftContractAddress, _tokenId)
    {
        require(
            msg.sender ==
                nftContractAuctions[_nftContractAddress][_tokenId].nftSeller,
            "Only the owner can withdraw their NFT"
        );

        nftContractAuctions[_nftContractAddress][_tokenId]
            ._nftContract
            .safeTransferFrom(
            address(this),
            nftContractAuctions[_nftContractAddress][_tokenId].nftSeller,
            _tokenId
        );
        _resetAuction(_nftContractAddress, _tokenId);
    }

    function withdrawBid(address _nftContractAddress, uint256 _tokenId)
        external
        minimumBidNotMade(_nftContractAddress, _tokenId)
    {
        require(
            msg.sender ==
                nftContractAuctions[_nftContractAddress][_tokenId]
                .nftHighestBidder,
            "Cannot withdraw funds"
        );

        _reversePreviousBid(_nftContractAddress, _tokenId);
        _resetBids(_nftContractAddress, _tokenId);
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
