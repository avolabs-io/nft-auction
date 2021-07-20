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
        uint32[] feePercentages;
        address nftHighestBidder;
        address nftSeller;
        address whiteListedBuyer;
        address nftRecipient;
        address ERC20Token;
        address[] feeRecipients;
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
            (10000 +
                _getBidIncreasePercentage(_nftContractAddress, _tokenId))) /
            10000;
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

    modifier isAuctionOver(address _nftContractAddress, uint256 _tokenId) {
        require(
            !_isAuctionOngoing(_nftContractAddress, _tokenId),
            "Auction is not yet over"
        );
        _;
    }

    modifier notZeroAddress(address _address) {
        require(_address != address(0), "cannot specify 0 address");
        _;
    }

    modifier increasePercentageAboveMinimum(uint256 _bidIncreasePercentage) {
        require(
            _bidIncreasePercentage >= minimumSettableIncreasePercentage,
            "Bid increase percentage must be greater than minimum settable increase percentage"
        );
        _;
    }

    modifier isFeePercentagesLessThanMaximum(uint32[] memory _feePercentages) {
        uint32 totalPercent;
        for (uint256 i = 0; i < _feePercentages.length; i++) {
            totalPercent = totalPercent + _feePercentages[i];
        }
        require(totalPercent <= 10000, "fee percentages exceed maximum");
        _;
    }

    modifier correctFeeRecipientsAndPercentages(
        uint256 _recipientsLength,
        uint256 _percentagesLength
    ) {
        require(
            _recipientsLength == _percentagesLength,
            "mismatched fee recipients and percentages"
        );
        _;
    }

    /**********************************/
    /*╔═════════════════════════════╗
      ║             END             ║
      ║          MODIFIERS          ║
      ╚═════════════════════════════╝*/
    /**********************************/
    // constructor
    constructor() {
        defaultBidIncreasePercentage = 10;
        defaultAuctionBidPeriod = 86400; //1 day
        minimumSettableIncreasePercentage = 500;
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

    /**
     * Payment is accepted in the following scenarios:
     * (1) Auction already created - can accept ETH or Specified Token
     *  --------> Cannot bid with ETH & an ERC20 Token together in any circumstance<------
     * (2) Auction not created - only ETH accepted (cannot early bid with an ERC20 Token
     * (3) Cannot make a zero bid (no ETH or Token amount)
     */
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

    function _getPaymentAmount(uint256 _totalBid, uint256 _percentage)
        internal
        pure
        returns (uint256)
    {
        return (_totalBid * (_percentage)) / 10000;
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║    AUCTION CHECK FUNCTIONS   ║
      ╚══════════════════════════════╝*/
    /**********************************/
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

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║    DEFAULT GETTER FUNCTIONS  ║
      ╚══════════════════════════════╝*/
    /**********************************/

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

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║  TRANSFER NFTS TO CONTRACT   ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║       AUCTION CREATION       ║
      ╚══════════════════════════════╝*/

    /**
     * Setup parameters applicable to all auctions and whitelised sales:
     * -> minimum price : _minPrice
     * -> the nft seller: msg.sender
     * -> The fee recipients & their respective percentages for a sucessful auction/sale
     */
    function _setupAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _minPrice,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    )
        internal
        auctionMinPriceGreaterThanZero(_minPrice)
        correctFeeRecipientsAndPercentages(
            _feeRecipients.length,
            _feePercentages.length
        )
        isFeePercentagesLessThanMaximum(_feePercentages)
    {
        if (_erc20Token != address(0)) {
            nftContractAuctions[_nftContractAddress][_tokenId]
            .ERC20Token = _erc20Token;
        }
        nftContractAuctions[_nftContractAddress][_tokenId]
        .feeRecipients = _feeRecipients;
        nftContractAuctions[_nftContractAddress][_tokenId]
        .feePercentages = _feePercentages;
        nftContractAuctions[_nftContractAddress][_tokenId].minPrice = _minPrice;
        nftContractAuctions[_nftContractAddress][_tokenId].nftSeller = msg
        .sender;
    }

    function _createNewNftAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _minPrice,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    ) internal {
        // Sending our contract the NFT
        _transferNftMasterToAuctionContract(_nftContractAddress, _tokenId);
        _setupAuction(
            _nftContractAddress,
            _tokenId,
            _erc20Token,
            _minPrice,
            _feeRecipients,
            _feePercentages
        );
        if (_isMinimumBidMade(_nftContractAddress, _tokenId)) {
            _updateAuctionEnd(_nftContractAddress, _tokenId);
        }
    }

    /**
     * Create an auction that uses the default bid increase percentage
     * & the default auction bid period
     */
    function createDefaultNftAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _minPrice,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    ) external {
        _createNewNftAuction(
            _nftContractAddress,
            _tokenId,
            _erc20Token,
            _minPrice,
            _feeRecipients,
            _feePercentages
        );

        emit DefaultNftAuctionCreated(_nftContractAddress, _tokenId, _minPrice);
    }

    function createNewNftAuction(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _minPrice,
        uint256 _auctionBidPeriod, //this is the time that the auction lasts until another bid occurs
        uint256 _bidIncreasePercentage,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    ) external increasePercentageAboveMinimum(_bidIncreasePercentage) {
        nftContractAuctions[_nftContractAddress][_tokenId]
        .auctionBidPeriod = _auctionBidPeriod;
        nftContractAuctions[_nftContractAddress][_tokenId]
        .bidIncreasePercentage = _bidIncreasePercentage;
        _createNewNftAuction(
            _nftContractAddress,
            _tokenId,
            _erc20Token,
            _minPrice,
            _feeRecipients,
            _feePercentages
        );

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
        uint256[] memory _layers,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    ) internal layersDoesNotExceedLimit(_layers.length) {
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
            _minPrice,
            _feeRecipients,
            _feePercentages
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
        uint256[] memory _layers,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    ) external {
        _createBatchNftAuction(
            _nftContractAddress,
            _tokenIdMaster,
            _erc20Token,
            _minPrice,
            _layers,
            _feeRecipients,
            _feePercentages
        );
    }

    function createBatchNftAuction(
        address _nftContractAddress,
        uint256 _tokenIdMaster,
        address _erc20Token,
        uint256 _minPrice,
        uint256[] memory _layers,
        uint256 _auctionBidPeriod, //this is the time that the auction lasts until another bid occurs
        uint256 _bidIncreasePercentage,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    ) external increasePercentageAboveMinimum(_bidIncreasePercentage) {
        nftContractAuctions[_nftContractAddress][_tokenIdMaster]
        .auctionBidPeriod = _auctionBidPeriod;
        nftContractAuctions[_nftContractAddress][_tokenIdMaster]
        .bidIncreasePercentage = _bidIncreasePercentage;
        _createBatchNftAuction(
            _nftContractAddress,
            _tokenIdMaster,
            _erc20Token,
            _minPrice,
            _layers,
            _feeRecipients,
            _feePercentages
        );
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       AUCTION CREATION       ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║       WHITELIST SALES        ║
      ╚══════════════════════════════╝*/

    /********************************************************************
     * Allows for a standard sale mechanism where the NFT seller can    *
     * can select an address to be whitelisted. This address is then    *
     * allowed to make a bid on the NFT. No other address can bid on    *
     * the NFT.                                                         *
     ********************************************************************/
    function _updateWhitelistedSale(
        address _nftContractAddress,
        uint256 _tokenId,
        address _erc20Token,
        uint256 _minPrice,
        address _whiteListedBuyer,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    ) internal {
        _setupAuction(
            _nftContractAddress,
            _tokenId,
            _erc20Token,
            _minPrice,
            _feeRecipients,
            _feePercentages
        );
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
        address _whiteListedBuyer,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    ) external {
        _transferNftMasterToAuctionContract(_nftContractAddress, _tokenId);
        _updateWhitelistedSale(
            _nftContractAddress,
            _tokenId,
            _erc20Token,
            _minPrice,
            _whiteListedBuyer,
            _feeRecipients,
            _feePercentages
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
        address _whiteListedBuyer,
        address[] memory _feeRecipients,
        uint32[] memory _feePercentages
    ) external layersDoesNotExceedLimit(_layers.length) {
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
            _whiteListedBuyer,
            _feeRecipients,
            _feePercentages
        );
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       WHITELIST SALES        ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔═════════════════════════════╗
      ║        BID FUNCTIONS        ║
      ╚═════════════════════════════╝*/

    /********************************************************************
     * Make bids with ETH or an ERC20 Token specified by the NFT seller.*
     * Additionally, a whitelisted buyer can pay the asking price       *
     * to conclude a whitelisted sale of an NFT.                        *
     ********************************************************************/

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

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║        BID FUNCTIONS         ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/

    /***********************************************************************
     * Update an ongoing auction by updating the highest bid and bidder and*
     * update auction period to begin if the minimum price has been met.   *
     ***********************************************************************/
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

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║       RESET FUNCTIONS        ║
      ╚══════════════════════════════╝*/

    /*
     * Reset all auction related parameters for an NFT.
     * This effectively removes an EFT as an item up for auction
     */
    function _resetAuction(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        nftContractAuctions[_nftContractAddress][_tokenId].minPrice = 0;
        nftContractAuctions[_nftContractAddress][_tokenId].auctionEnd = 0;
        nftContractAuctions[_nftContractAddress][_tokenId].auctionBidPeriod = 0;
        nftContractAuctions[_nftContractAddress][_tokenId]
        .bidIncreasePercentage = 0;
        nftContractAuctions[_nftContractAddress][_tokenId].nftSeller = address(
            0
        );
        nftContractAuctions[_nftContractAddress][_tokenId]
        .whiteListedBuyer = address(0);
        delete nftContractAuctions[_nftContractAddress][_tokenId].layers;
        nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token = address(
            0
        );
    }

    /*
     * Reset all bid related parameters for an NFT.
     * This effectively sets an NFT as having no active bids
     */
    function _resetBids(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        nftContractAuctions[_nftContractAddress][_tokenId]
        .nftHighestBidder = address(0);
        nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid = 0;
        nftContractAuctions[_nftContractAddress][_tokenId]
        .nftRecipient = address(0);
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       RESET FUNCTIONS        ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║         UPDATE BIDS          ║
      ╚══════════════════════════════╝*/
    /******************************************************************
     * Internal functions that update bid parameters and reverse bids *
     * to ensure contract only holds the highest bid.                 *
     ******************************************************************/
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

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║         UPDATE BIDS          ║
      ╚══════════════════════════════╝*/
    /**********************************/

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

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║   CONCLUDE WHITELIST SALE    ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║  TRANSFER NFT & PAY SELLER   ║
      ╚══════════════════════════════╝*/
    function _transferNftAndPaySeller(
        address _nftContractAddress,
        uint256 _tokenId
    ) internal {
        _payFeesAndSeller(_nftContractAddress, _tokenId);
        address nftRecipient = _getNftRecipient(_nftContractAddress, _tokenId);
        _resetBids(_nftContractAddress, _tokenId);
        //reset bid and transfer nft last to avoid reentrancy
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

    function _payFeesAndSeller(address _nftContractAddress, uint256 _tokenId)
        internal
    {
        uint256 paymentAmountTotal;
        uint256 highestBid = nftContractAuctions[_nftContractAddress][_tokenId]
        .nftHighestBid;
        //payfees
        for (
            uint256 i = 0;
            i <
            nftContractAuctions[_nftContractAddress][_tokenId]
            .feeRecipients
            .length;
            i++
        ) {
            uint256 paymentAmount = _getPaymentAmount(
                highestBid,
                nftContractAuctions[_nftContractAddress][_tokenId]
                .feePercentages[i]
            );
            paymentAmountTotal = paymentAmountTotal + paymentAmount;
            _payout(
                _nftContractAddress,
                _tokenId,
                nftContractAuctions[_nftContractAddress][_tokenId]
                    .feeRecipients[i],
                paymentAmount
            );
        }
        _payout(
            _nftContractAddress,
            _tokenId,
            nftContractAuctions[_nftContractAddress][_tokenId].nftSeller,
            (highestBid - paymentAmountTotal)
        );
    }

    function _payoutHighestBid(
        address _nftContractAddress,
        uint256 _tokenId,
        address _recipient
    ) internal {
        _payout(
            _nftContractAddress,
            _tokenId,
            _recipient,
            nftContractAuctions[_nftContractAddress][_tokenId].nftHighestBid
        );
    }

    function _payout(
        address _nftContractAddress,
        uint256 _tokenId,
        address _recipient,
        uint256 _amount
    ) internal {
        if (_isERC20Auction(_nftContractAddress, _tokenId)) {
            IERC20 erc20Token = IERC20(
                nftContractAuctions[_nftContractAddress][_tokenId].ERC20Token
            );
            erc20Token.approve(address(this), _amount);
            erc20Token.safeTransferFrom(address(this), _recipient, _amount);
        } else {
            payable(_recipient).transfer(_amount);
        }
    }

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║  TRANSFER NFT & PAY SELLER   ║
      ╚══════════════════════════════╝*/
    /**********************************/

    /*╔══════════════════════════════╗
      ║      SETTLE & WITHDRAW       ║
      ╚══════════════════════════════╝*/
    function settleAuction(address _nftContractAddress, uint256 _tokenId)
        external
        isAuctionOver(_nftContractAddress, _tokenId)
    {
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

    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║      SETTLE & WITHDRAW       ║
      ╚══════════════════════════════╝*/
    /**********************************/

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
    /**********************************/
    /*╔══════════════════════════════╗
      ║             END              ║
      ║       UPDATE AUCTION         ║
      ╚══════════════════════════════╝*/
    /**********************************/
}
