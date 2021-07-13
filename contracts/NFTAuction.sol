//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NFTAuction {
    using SafeERC20 for IERC20;
    mapping(address => mapping(uint256 => Auction)) public nftContractAuctions;

    //Each Auction is unique to each NFT (contract + id master pairing)
    struct Auction {
        //map token ID to
        IERC721 _nftContract;
        uint256 minPrice;
        uint256 auctionBidPeriod; //Length of time the auction is open in which a new bid can be made
        uint256 auctionEnd;
        uint256 nftHighestBid;
        uint256 bidIncreasePercentage;
        uint256[] layers;
        address nftHighestBidder;
        address nftSeller;
        address whiteListedBuyer;
        address nftRecipient;
        address ERC20Token;
    }
    uint256 public defaultBidIncreasePercentage;
    uint256 public defaultAuctionBidPeriod;
    uint256 public minimumSettableIncreasePercentage;

    /*╔═════════════════════════════╗
      ║           EVENTS            ║
      ╚═════════════════════════════╝*/

    event DefaultNftAuctionCreated(
        address nftContractAddress,
        uint256 tokenId,
        uint256 minPrice
    );

    event NftAuctionCreated(
        address nftContractAddress,
        uint256 tokenId,
        uint256 minPrice,
        uint256 auctionBidPeriod,
        uint256 bidIncreasePercentage
    );

    event WhiteListSaleCreated(
        address nftContractAddress,
        uint256 tokenId,
        uint256 minPrice,
        address whiteListedBuyer
    );

    event AuctionSettled(address nftContractAddress, uint256 tokenId);

    /*╔═════════════════════════════╗
      ║          MODIFIERS          ║
      ╚═════════════════════════════╝*/

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
    modifier onlyNftSeller(address _nftContractAddress, uint256 _tokenId) {
        require(
            msg.sender ==
                nftContractAuctions[_nftContractAddress][_tokenId].nftSeller,
            "Only the owner can call this function"
        );
        _;
    }

    modifier bidExceedsMinPrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _tokenAmount
    ) {
        require(
            msg.value >=
                nftContractAuctions[_nftContractAddress][_tokenId].minPrice ||
                _tokenAmount >=
                nftContractAuctions[_nftContractAddress][_tokenId].minPrice,
            "Bid must be higher than minimum bid"
        );
        _;
    }

    modifier bidAmountMeetsBidRequirements(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _tokenAmount
    ) {
        uint256 bidIncreaseAmount = (nftContractAuctions[_nftContractAddress][
            _tokenId
        ]
        .nftHighestBid *
            (100 + _getBidIncreasePercentage(_nftContractAddress, _tokenId))) /
            100;
        require(
            msg.value >= bidIncreaseAmount || _tokenAmount >= bidIncreaseAmount,
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

    modifier layersDoesNotExceedLimit(uint256 _layersLength) {
        require(_layersLength <= 100, "Too many NFTs sent");
        _;
    }
    modifier paymentAccepted(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token
    ) {
        require(
            _isPaymentAccepted(_nftContractAddress, _tokenId, _erc20Token),
            "Bid to be made in quantities of specified token or eth"
        );
        _;
    }

    modifier notZeroAddress(address _address) {
        require(_address != address(0), "cannot specify 0 address");
        _;
    }

    // constructor
    constructor() {
        defaultBidIncreasePercentage = 10;
        defaultAuctionBidPeriod = 86400; //1 day
        minimumSettableIncreasePercentage = 5;
    }

    /*╔══════════════════════════════╗
      ║    AUCTION CHECK FUNCTIONS   ║
      ╚══════════════════════════════╝*/

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

    function _isWhitelistedSale(address _nftContractAddress, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        return (nftContractAuctions[_nftContractAddress][_tokenId]
        .whiteListedBuyer != address(0));
    }

    function _isABidMade(address _nftContractAddress, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        return (nftContractAuctions[_nftContractAddress][_tokenId]
        .nftHighestBid > 0);
    }

    function _isHighestBidderWhitelisted(
        address _nftContractAddress,
        uint256 _tokenId
    ) internal view returns (bool) {
        return (nftContractAuctions[_nftContractAddress][_tokenId]
        .nftHighestBidder ==
            nftContractAuctions[_nftContractAddress][_tokenId]
            .whiteListedBuyer);
    }

    function _isPaymentAccepted(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token
    ) internal view returns (bool) {
        if (_isERC20Auction(_nftContractAddress, _tokenId)) {
            return
                msg.value == 0 &&
                nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token ==
                _erc20Token;
        } else {
            return msg.value != 0 && _erc20Token == address(0);
        }
    }

    function _isERC20Auction(address _nftContractAddress, uint256 _tokenId)
        internal
        view
        returns (bool)
    {
        return
            nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token !=
            address(0);
    }

    /*╔══════════════════════════════╗
      ║    DEFAULT GETTER FUNCTIONS  ║
      ╚══════════════════════════════╝*/
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

    function _getNftRecipient(address _nftContractAddress, uint256 _tokenId)
        internal
        view
        returns (address)
    {
        if (
            nftContractAuctions[_nftContractAddress][_tokenId].nftRecipient ==
            address(0)
        ) {
            return
                nftContractAuctions[_nftContractAddress][_tokenId]
                    .nftHighestBidder;
        } else {
            return
                nftContractAuctions[_nftContractAddress][_tokenId].nftRecipient;
        }
    }

    /*╔══════════════════════════════╗
      ║  TRANSFER NFTS TO CONTRACT   ║
      ╚══════════════════════════════╝*/
    function _transferNftMasterToAuctionContract(
        address _nftContractAddress,
        uint256 _tokenId
    ) internal {
        IERC721 nftContract = IERC721(_nftContractAddress);
        nftContract.transferFrom(msg.sender, address(this), _tokenId);

        //Store the token id, token contract and minimum price
        nftContractAuctions[_nftContractAddress][_tokenId]
        ._nftContract = nftContract;
    }

    function _transferNftLayersToAuctionContract(
        address _nftContractAddress,
        uint256 _tokenIdMaster,
        uint256[] memory _layers
    ) internal {
        uint256 i;

        for (i = 0; i < _layers.length; i++) {
            nftContractAuctions[_nftContractAddress][_tokenIdMaster]
                ._nftContract
                .transferFrom(msg.sender, address(this), _layers[i]);
        }
        nftContractAuctions[_nftContractAddress][_tokenIdMaster]
        .layers = _layers;
    }

    /*╔══════════════════════════════╗
      ║       AUCTION CREATION       ║
      ╚══════════════════════════════╝*/
    function _setupAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _minPrice
    ) internal {
        if (_erc20Token != address(0)) {
            nftContractAuctions[_nftContractAddress][_tokenId]
            .ERC20Token = _erc20Token;
        }
        nftContractAuctions[_nftContractAddress][_tokenId].minPrice = _minPrice;
        nftContractAuctions[_nftContractAddress][_tokenId].nftSeller = msg
        .sender;
    }

    function _createNewNftAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _minPrice
    ) internal auctionMinPriceGreaterThanZero(_minPrice) {
        // Sending our contract the NFT
        _transferNftMasterToAuctionContract(_nftContractAddress, _tokenId);
        _setupAuction(_nftContractAddress, _tokenId, _erc20Token, _minPrice);
        if (_isMinimumBidMade(_nftContractAddress, _tokenId)) {
            _updateAuctionEnd(_nftContractAddress, _tokenId);
        }
    }

    function createDefaultNftAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _minPrice
    ) external {
        _createNewNftAuction(
            _nftContractAddress,
            _tokenId,
            _erc20Token,
            _minPrice
        );

        emit DefaultNftAuctionCreated(_nftContractAddress, _tokenId, _minPrice);
    }

    function createNewNftAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _minPrice,
        uint256 _auctionBidPeriod, //this is the time that the auction lasts until another bid occurs
        uint256 _bidIncreasePercentage
    ) external {
        require(
            _bidIncreasePercentage >= minimumSettableIncreasePercentage,
            "Bid increase percentage must be greater than minimum settable increase percentage"
        );
        _createNewNftAuction(
            _nftContractAddress,
            _tokenId,
            _erc20Token,
            _minPrice
        );

        nftContractAuctions[_nftContractAddress][_tokenId]
        .auctionBidPeriod = _auctionBidPeriod;
        nftContractAuctions[_nftContractAddress][_tokenId]
        .bidIncreasePercentage = _bidIncreasePercentage;

        emit NftAuctionCreated(
            _nftContractAddress,
            _tokenId,
            _minPrice,
            _auctionBidPeriod,
            _bidIncreasePercentage
        );
    }

    function _createBatchNftAuction(
        address _nftContractAddress,
        uint256 _tokenIdMaster,
        address _erc20Token,
        uint256 _minPrice,
        uint256[] memory _layers
    )
        internal
        auctionMinPriceGreaterThanZero(_minPrice)
        layersDoesNotExceedLimit(_layers.length)
    {
        _transferNftMasterToAuctionContract(
            _nftContractAddress,
            _tokenIdMaster
        );
        _transferNftLayersToAuctionContract(
            _nftContractAddress,
            _tokenIdMaster,
            _layers
        );
        _setupAuction(
            _nftContractAddress,
            _tokenIdMaster,
            _erc20Token,
            _minPrice
        );
        if (_isMinimumBidMade(_nftContractAddress, _tokenIdMaster)) {
            _updateAuctionEnd(_nftContractAddress, _tokenIdMaster);
        }
    }

    function createDefaultBatchNftAuction(
        address _nftContractAddress,
        uint256 _tokenIdMaster,
        address _erc20Token,
        uint256 _minPrice,
        uint256[] memory _layers
    ) external {
        _createBatchNftAuction(
            _nftContractAddress,
            _tokenIdMaster,
            _erc20Token,
            _minPrice,
            _layers
        );
    }

    function createBatchNftAuction(
        address _nftContractAddress,
        uint256 _tokenIdMaster,
        address _erc20Token,
        uint256 _minPrice,
        uint256[] memory _layers,
        uint256 _auctionBidPeriod, //this is the time that the auction lasts until another bid occurs
        uint256 _bidIncreasePercentage
    ) external {
        _createBatchNftAuction(
            _nftContractAddress,
            _tokenIdMaster,
            _erc20Token,
            _minPrice,
            _layers
        );
        nftContractAuctions[_nftContractAddress][_tokenIdMaster]
        .auctionBidPeriod = _auctionBidPeriod;
        nftContractAuctions[_nftContractAddress][_tokenIdMaster]
        .bidIncreasePercentage = _bidIncreasePercentage;
    }

    /*╔══════════════════════════════╗
      ║       WHITELIST SALES        ║
      ╚══════════════════════════════╝*/
    function _updateWhitelistedSale(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _minPrice,
        address _whiteListedBuyer
    ) internal {
        _setupAuction(_nftContractAddress, _tokenId, _erc20Token, _minPrice);
        nftContractAuctions[_nftContractAddress][_tokenId]
        .whiteListedBuyer = _whiteListedBuyer;
        //check if min bid made and conclude sale, or send money back to not whitelisted buyer
        if (_isABidMade(_nftContractAddress, _tokenId)) {
            if (
                _isHighestBidderWhitelisted(_nftContractAddress, _tokenId) &&
                _isMinimumBidMade(_nftContractAddress, _tokenId)
            ) {
                _transferNftAndPaySeller(_nftContractAddress, _tokenId);
            } else {
                _reversePreviousBid(_nftContractAddress, _tokenId);
                _resetBids(_nftContractAddress, _tokenId);
            }
        }
    }

    function createWhiteListSale(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _minPrice,
        address _whiteListedBuyer
    ) external auctionMinPriceGreaterThanZero(_minPrice) {
        _transferNftMasterToAuctionContract(_nftContractAddress, _tokenId);
        _updateWhitelistedSale(
            _nftContractAddress,
            _tokenId,
            _erc20Token,
            _minPrice,
            _whiteListedBuyer
        );

        emit WhiteListSaleCreated(
            _nftContractAddress,
            _tokenId,
            _minPrice,
            _whiteListedBuyer
        );
    }

    function createBatchWhiteListSale(
        address _nftContractAddress,
        uint256 _tokenIdMaster,
        address _erc20Token,
        uint256 _minPrice,
        uint256[] memory _layers,
        address _whiteListedBuyer
    )
        external
        auctionMinPriceGreaterThanZero(_minPrice)
        layersDoesNotExceedLimit(_layers.length)
    {
        _transferNftMasterToAuctionContract(
            _nftContractAddress,
            _tokenIdMaster
        );
        _transferNftLayersToAuctionContract(
            _nftContractAddress,
            _tokenIdMaster,
            _layers
        );
        _updateWhitelistedSale(
            _nftContractAddress,
            _tokenIdMaster,
            _erc20Token,
            _minPrice,
            _whiteListedBuyer
        );
    }

    /*╔═════════════════════════════╗
      ║        BID FUNCTIONS        ║
      ╚═════════════════════════════╝*/

    function _makeBid(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _tokenAmount
    )
        internal
        auctionOngoing(_nftContractAddress, _tokenId)
        notNftSeller(_nftContractAddress, _tokenId)
        bidAmountMeetsBidRequirements(
            _nftContractAddress,
            _tokenId,
            _tokenAmount
        )
    {
        _updateOngoingAuction(_nftContractAddress, _tokenId, _tokenAmount);
    }

    //Add the functionality that holds the auction until first bid.
    // the auction time should then kick off
    //each new bid should add time to the auction length
    //each new bid should increase by a percentage
    function makeBid(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _tokenAmount
    )
        public
        payable
        paymentAccepted(_nftContractAddress, _tokenId, _erc20Token)
    {
        if (_isWhitelistedSale(_nftContractAddress, _tokenId)) {
            _concludeWhitelistSale(_nftContractAddress, _tokenId, _tokenAmount);
        } else {
            _makeBid(_nftContractAddress, _tokenId, _tokenAmount);
        }
    }

    function makeCustomBid(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _tokenAmount,
        address _nftRecipient
    )
        external
        payable
        notZeroAddress(_nftRecipient)
        paymentAccepted(_nftContractAddress, _tokenId, _erc20Token)
    {
        if (_isWhitelistedSale(_nftContractAddress, _tokenId)) {
            _concludeCustomWhitelistSale(
                _nftContractAddress,
                _tokenId,
                _tokenAmount,
                _nftRecipient
            );
        } else {
            _makeBid(_nftContractAddress, _tokenId, _tokenAmount);
            nftContractAuctions[_nftContractAddress][_tokenId]
            .nftRecipient = _nftRecipient;
        }
    }

    /*╔══════════════════════════════╗
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/
    function _updateOngoingAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _tokenAmount
    ) internal {
        _reversePreviousBidAndUpdateHighestBid(
            _nftContractAddress,
            _tokenId,
            _tokenAmount
        );
        //min price not set, nft not up for auction yet
        if (_isMinimumBidMade(_nftContractAddress, _tokenId)) {
            _updateAuctionEnd(_nftContractAddress, _tokenId);
        }
    }

    function _updateAuctionEnd(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        //the auction end is always set to now + the period
        nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd =
            _getAuctionBidPeriod(_nftContractAddress, _tokenId) +
            block.timestamp;
    }

    /*╔══════════════════════════════╗
      ║       RESET FUNCTIONS        ║
      ╚══════════════════════════════╝*/
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
        delete nftContractAuctions[_nftContractAddress][_tokenId].layers;
        nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token = address(
            0
        );
    }

    function _resetBids(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        nftContractAuctions[_nftContractAddress][_tokenId]
        .nftHighestBidder = address(0);
        nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid = 0;
        nftContractAuctions[_nftContractAddress][_tokenId]
        .nftRecipient = address(0);
    }

    /*╔══════════════════════════════╗
      ║         UPDATE BIDS          ║
      ╚══════════════════════════════╝*/
    function _updateHighestBid(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _tokenAmount
    ) internal {
        if (_isERC20Auction(_nftContractAddress, _tokenId)) {
            IERC20 erc20Token = IERC20(
                nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token
            );
            erc20Token.safeTransferFrom(
                msg.sender,
                address(this),
                _tokenAmount
            );
            nftContractAuctions[_nftContractAddress][_tokenId]
            .nftHighestBid = _tokenAmount;
        } else {
            nftContractAuctions[_nftContractAddress][_tokenId]
            .nftHighestBid = msg.value;
        }
        nftContractAuctions[_nftContractAddress][_tokenId]
        .nftHighestBidder = msg.sender;
    }

    function _reversePreviousBid(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        _payoutHighestBid(
            _nftContractAddress,
            _tokenId,
            nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBidder
        );
    }

    function _reversePreviousBidAndUpdateHighestBid(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _tokenAmount
    ) internal {
        if (
            nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid > 0
        ) {
            _reversePreviousBid(_nftContractAddress, _tokenId);
        }

        _updateHighestBid(_nftContractAddress, _tokenId, _tokenAmount);
    }

    function _updateHighestBidAndTransferNft(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _tokenAmount
    ) internal {
        _updateHighestBid(_nftContractAddress, _tokenId, _tokenAmount); //no previous bid made
        _transferNftAndPaySeller(_nftContractAddress, _tokenId);
    }

    /*╔══════════════════════════════╗
      ║   CONCLUDE WHITELIST SALE    ║
      ╚══════════════════════════════╝*/
    function _concludeCustomWhitelistSale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _tokenAmount,
        address _nftRecipient
    )
        internal
        onlyWhitelistedBuyer(_nftContractAddress, _tokenId)
        bidExceedsMinPrice(_nftContractAddress, _tokenId, _tokenAmount)
    {
        nftContractAuctions[_nftContractAddress][_tokenId]
        .nftRecipient = _nftRecipient;
        _updateHighestBidAndTransferNft(
            _nftContractAddress,
            _tokenId,
            _tokenAmount
        );
    }

    function _concludeWhitelistSale(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _tokenAmount
    )
        internal
        onlyWhitelistedBuyer(_nftContractAddress, _tokenId)
        bidExceedsMinPrice(_nftContractAddress, _tokenId, _tokenAmount)
    {
        _updateHighestBidAndTransferNft(
            _nftContractAddress,
            _tokenId,
            _tokenAmount
        );
    }

    /*╔══════════════════════════════╗
      ║  TRANSFER NFT & PAY SELLER   ║
      ╚══════════════════════════════╝*/
    function _transferNftAndPaySeller(
        address _nftContractAddress,
        uint256 _tokenId
    ) internal {
        _payoutHighestBid(
            _nftContractAddress,
            _tokenId,
            nftContractAuctions[_nftContractAddress][_tokenId].nftSeller
        );
        address nftRecipient = _getNftRecipient(_nftContractAddress, _tokenId);
        _resetBids(_nftContractAddress, _tokenId);
        //reset all params and transfer nft last to avoid reentrancy
        if (
            nftContractAuctions[_nftContractAddress][_tokenId].layers.length > 0
        ) {
            for (
                uint256 i = 0;
                i <
                nftContractAuctions[_nftContractAddress][_tokenId]
                .layers
                .length;
                i++
            ) {
                nftContractAuctions[_nftContractAddress][_tokenId]
                    ._nftContract
                    .transferFrom(
                    address(this),
                    nftRecipient,
                    nftContractAuctions[_nftContractAddress][_tokenId].layers[i]
                );
            }
        }
        nftContractAuctions[_nftContractAddress][_tokenId]
            ._nftContract
            .transferFrom(address(this), nftRecipient, _tokenId);

        _resetAuction(_nftContractAddress, _tokenId);
    }

    function _payoutHighestBid(
        address _nftContractAddress,
        uint256 _tokenId,
        address _recipient
    ) internal {
        if (_isERC20Auction(_nftContractAddress, _tokenId)) {
            IERC20 erc20Token = IERC20(
                nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token
            );
            erc20Token.approve(
                address(this),
                nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid
            );
            erc20Token.safeTransferFrom(
                address(this),
                _recipient,
                nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid
            );
        } else {
            payable(_recipient).transfer(
                nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid
            );
        }
    }

    /*╔══════════════════════════════╗
      ║      SETTLE & WITHDRAW       ║
      ╚══════════════════════════════╝*/
    function settleAuction(address _nftContractAddress, uint256 _tokenId)
        external
    {
        require(
            !_isAuctionOngoing(_nftContractAddress, _tokenId),
            "Auction is not yet over"
        );
        _transferNftAndPaySeller(_nftContractAddress, _tokenId);
        emit AuctionSettled(_nftContractAddress, _tokenId);
    }

    function withdrawNft(address _nftContractAddress, uint256 _tokenId)
        external
        minimumBidNotMade(_nftContractAddress, _tokenId)
        onlyNftSeller(_nftContractAddress, _tokenId)
    {
        if (
            nftContractAuctions[_nftContractAddress][_tokenId].layers.length > 0
        ) {
            for (
                uint256 i = 0;
                i <
                nftContractAuctions[_nftContractAddress][_tokenId]
                .layers
                .length;
                i++
            ) {
                nftContractAuctions[_nftContractAddress][_tokenId]
                    ._nftContract
                    .transferFrom(
                    address(this),
                    nftContractAuctions[_nftContractAddress][_tokenId]
                        .nftSeller,
                    nftContractAuctions[_nftContractAddress][_tokenId].layers[i]
                );
            }
        }
        nftContractAuctions[_nftContractAddress][_tokenId]
            ._nftContract
            .transferFrom(
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

    /*╔══════════════════════════════╗
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/
    function updateWhitelistedBuyer(
        address _nftContractAddress,
        uint256 _tokenId,
        address _newWhiteListedBuyer
    ) external onlyNftSeller(_nftContractAddress, _tokenId) {
        require(
            _isWhitelistedSale(_nftContractAddress, _tokenId),
            "Not a whitelisted sale"
        );
        nftContractAuctions[_nftContractAddress][_tokenId]
        .whiteListedBuyer = _newWhiteListedBuyer;
    }

    function updateMinimumPrice(
        address _nftContractAddress,
        uint256 _tokenId,
        uint256 _newMinPrice
    )
        external
        onlyNftSeller(_nftContractAddress, _tokenId)
        minimumBidNotMade(_nftContractAddress, _tokenId)
    {
        nftContractAuctions[_nftContractAddress][_tokenId]
        .minPrice = _newMinPrice;
        if (_isMinimumBidMade(_nftContractAddress, _tokenId)) {
            _updateAuctionEnd(_nftContractAddress, _tokenId);
        }
    }
}
