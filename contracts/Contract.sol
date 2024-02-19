// SPDX-License-Identifier: MIT
/*
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒███▓▓▓▓▓███▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒██▓░░░░░▒██▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒██▓░░░░░▒██▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒██▓░░░░░▒██▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒██▓░░░░░▒███████████▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒██▓░░░░░▒██▓░░░░░▒██▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒██▓░░░░░▒██▓░░░░░▒██▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒██▓░░░░░▒██▓░░░░░▒██▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒██▓░░░░░▒██▓░░░░░▒██▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒██▓░░░░░▒██▓░░░░░▒██▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░▒██▓░░░░░▒██▓░░░░░▒██▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░▒██████████████████████████▒░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 */
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "operator-filter-registry-1.3.1/src/DefaultOperatorFilterer.sol";
import "./lib/auctions/DutchAuctionHouse.sol";
import "./lib/auctions/EnglishAuctionHouse.sol";
import "./lib/MerkleFourParams.sol";
import "./lib/IWCNFTErrorCodes.sol";
import "./lib/WCNFTToken.sol";

contract CryptoCitiesSuburbs is
    IWCNFTErrorCodes,
    ReentrancyGuard,
    DefaultOperatorFilterer,
    DutchAuctionHouse,
    EnglishAuctionHouse,
    MerkleFourParams,
    Ownable,
    WCNFTToken,
    ERC721
{
    // Structs
    struct City {
        uint256 id;
        uint256 numberOfSuburbs;
        uint256 minTokenId;
        uint256 maxTokenId; // inclusive
        string name; // e.g. Neo Tokyo
        string baseURIExtended;
        mapping(uint256 => Suburb) suburbs; // first Suburb has id 1
    }

    struct Suburb {
        uint256 id; // 1, 2, 3... etc. local to each City, starts at 1
        uint256 cityId; // parent City
        uint256 dutchAuctionId; // identifier of current DutchAuction, see DutchAuctionHouse.sol
        uint256 englishAuctionId; // identifier of current EnglishAuction, see EnglishAuctionHouse.sol
        uint256 firstTokenId;
        uint256 maxSupply;
        uint256 currentSupply;
        uint256 pricePerToken;
        uint256 allowListPricePerToken;
        bool allowListActive;
        bool saleActive;
    }

    // State vars
    uint256 public numberOfCities;
    uint256 public totalSupply; // cumulative over all cities and suburbs
    uint256 public maxDutchAuctionMints = 1;
    string private _baseURIOverride; // override per-City baseURIs
    address public immutable shareholderAddress;

    // map the Cities
    mapping(uint256 => City) public cities; // first City has id 1

    /**************************************************************************
     * CUSTOM ERRORS
     */

    /// unable to find the City for this token
    error CityNotFound();

    /// cities and suburbs cannot be removed if they are not empty
    error CityOrSuburbNotEmpty();

    /// action would exceed token or mint allowance
    error ExceedsMaximumTokensDuringDutchAuction();

    /// action would exceed the maximum token supply of this Suburb
    error ExceedsSuburbMaximumSupply();

    /// an invalid cityId has been requested
    error InvalidCityId();

    /// cannot initialize a Suburb with zero supply
    error InvalidInputZeroSupply();

    /// an invalid Suburb has been requested
    error InvalidSuburbId();

    /// an invalid tokenId has been requested. Often it is out of bounds
    error InvalidTokenId();

    /// only the most recent City can be modified
    error NotTheMostRecentCity();

    /// only the most recent Suburb can be modified
    error NotTheMostRecentSuburb();

    /// cannot add new City if previous has no suburbs. addSuburb or removeCity
    error PreviousCityHasNoSuburbs();

    /// Refund unsuccessful
    error RefundFailed();

    /// cannot complete request when a sale or allowlist is active
    error SaleIsActive();

    /**************************************************************************
     * EVENTS
     */

    /**
     * @dev emitted when a Dutch auction is created and assigned to a Suburb
     * @param cityId the City hosting the Dutch auction
     * @param suburbId the Suburb hosting the Dutch auction
     * @param dutchAuctionId auction ID, see {DutchAuctionHouse}
     */
    event DutchAuctionCreatedInSuburb(
        uint256 indexed cityId,
        uint256 indexed suburbId,
        uint256 dutchAuctionId
    );

    /**
     * @dev emitted when an English Auction is created and assigned to a Suburb
     * @param cityId the City hosting the Dutch auction
     * @param suburbId the Suburb hosting the Dutch auction
     * @param englishAuctionId auction ID, see EnglishAuctionHouse.sol
     */
    event EnglishAuctionCreatedInSuburb(
        uint256 indexed cityId,
        uint256 indexed suburbId,
        uint256 englishAuctionId
    );

    /**************************************************************************
     * CONSTRUCTOR
     */

    /**
     * @dev CryptoSuburbs tokens represent lots belonging to SUBURBS of CITIES
     * @param shareholderAddress_ Recipient address for contract funds.
     */
    constructor(address payable shareholderAddress_)
        ERC721("Suburbs", "SUBURBS")
        WCNFTToken()
    {
        if (shareholderAddress_ == address(0)) revert ZeroAddressProvided();
        shareholderAddress = shareholderAddress_;
    }

    /**************************************************************************
     * GUARD FUNCTIONS
     */

    /**
     * @dev reverts if the cityId or suburbId is invalid / does not exist
     * @param cityId city ID to query
     * @param suburbId suburb ID to query
     */
    function _revertIfCityIdOrSuburbIdInvalid(uint256 cityId, uint256 suburbId)
        internal
        view
    {
        if (cityId == 0 || cityId > numberOfCities) revert InvalidCityId();
        if (suburbId == 0 || suburbId > cities[cityId].numberOfSuburbs) {
            revert InvalidSuburbId();
        }
    }

    /**
     * @dev reverts if the public sale or allow list is active in Suburb s
     * @param s Suburb to query
     */
    function _revertIfAnySaleActive(Suburb storage s) internal view {
        if (s.saleActive) revert SaleIsActive();
        if (s.allowListActive) revert AllowListIsActive();
    }

    /**
     * @dev reverts if a Dutch auction or English Auction is active in Suburb s
     * @param s Suburb to query
     */
    function _revertIfAnyAuctionActive(Suburb storage s) internal view {
        if (_checkDutchAuctionActive(s.dutchAuctionId)) {
            revert DutchAuctionIsActive();
        }

        // revert if an EA is active, or is ended-but-not-settled
        if (_englishAuctionActiveNotSettled(s.englishAuctionId)) {
            revert EnglishAuctionIsNotComplete();
        }
    }

    /**************************************************************************
     * SETUP FUNCTIONS - build cities and suburbs
     */

    /**
     * @notice add a new City to the contract
     * @dev By adding a new City, the previous City is LOCKED and no more
     *  suburbs can be added to it.
     *
     *  New Cities are initialized without suburbs and without baseURI - these
     *  must be added with addSuburb() and setBaseURI()
     * @param cityName A name for the City, e.g. "Neo Tokyo"
     * @return cityId id for the City - use in cities(cityId) to get City info
     */
    function addCity(string calldata cityName)
        external
        onlyRole(SUPPORT_ROLE)
        returns (uint256)
    {
        // new ID number, start at 1
        uint256 cityId = ++numberOfCities;

        if (cityId > 1 && cities[cityId - 1].numberOfSuburbs == 0) {
            revert PreviousCityHasNoSuburbs();
        }

        // starting token ID for this City: refer to previous City
        // first token is ID 1 - consistent with cityId/suburbId
        uint256 startingTokenId = cities[cityId - 1].maxTokenId + 1;

        // make a new City struct and add it to cities
        City storage c = cities[cityId];

        // init the City
        c.id = cityId;
        c.minTokenId = startingTokenId;
        c.maxTokenId = startingTokenId; // will increase when adding suburbs
        c.name = cityName;

        return cityId;
    }

    /**
     * @notice add a new Suburb to the current City under construction.
     * @dev Suburbs can only be added to the most recently added City
     *  i.e. the City with the highest ID.
     * @param cityId_ the City to add a Suburb to. Must be the current City.
     * @param maxSupplyInSuburb the number of available tokens in this Suburb,
     *  including all sale types.
     * @param pricePerToken_ price per token in wei, on the public sale.
     * @param allowListPricePerToken_ allowList price per token in wei. Set to
     *  an arbitrary value if there will be no allow list sale for this Suburb.
     * @return newSuburbId ID for the newly created Suburb - use in
     *  suburbs(cityId, suburbId) to get Suburb info.
     */
    function addSuburb(
        uint256 cityId_,
        uint256 maxSupplyInSuburb,
        uint256 pricePerToken_,
        uint256 allowListPricePerToken_
    ) external onlyRole(SUPPORT_ROLE) returns (uint256) {
        // Incrementing token IDs means suburbs can only be added to the most
        // recent City
        if (cityId_ != numberOfCities || cityId_ == 0) {
            revert NotTheMostRecentCity();
        }
        if (maxSupplyInSuburb == 0) revert InvalidInputZeroSupply();

        City storage c = cities[cityId_];
        uint256 newSuburbId = ++c.numberOfSuburbs; // also increments storage

        // set the first and last token IDs in the new Suburb
        Suburb storage previousSub = c.suburbs[newSuburbId - 1];
        uint256 firstTokenId_ = newSuburbId > 1
            ? previousSub.firstTokenId + previousSub.maxSupply
            : c.minTokenId; // first Suburb, avoid setting first token as 0
        uint256 highestTokenId = firstTokenId_ + maxSupplyInSuburb - 1;

        // update max token tracker in the City
        c.maxTokenId = highestTokenId;

        // init the new Suburb
        c.suburbs[newSuburbId] = Suburb({
            id: newSuburbId,
            cityId: cityId_,
            firstTokenId: firstTokenId_,
            maxSupply: maxSupplyInSuburb,
            currentSupply: 0,
            pricePerToken: pricePerToken_,
            allowListPricePerToken: allowListPricePerToken_,
            dutchAuctionId: 0,
            englishAuctionId: 0,
            allowListActive: false,
            saleActive: false
        });

        return newSuburbId;
    }

    /**
     * @dev If and only if the most recent City is EMPTY, it can be removed.
     *  This will allow the previous City to add more Suburbs etc.
     *
     *  Intended for accidentally added cities (e.g. multiple/stuck txs).
     *
     *  User must confirm the cityId as a sanity check, even though it must be
     *  the most recently constructed City.
     *
     * @param cityId the City to be removed. Must be the most recently
     *  constructed City.
     */
    function removeCity(uint256 cityId) external onlyRole(SUPPORT_ROLE) {
        // revert if not the most recent City
        if (cityId != numberOfCities || cityId == 0) {
            revert NotTheMostRecentCity();
        }

        // revert if any suburbs have been built
        if (cities[cityId].numberOfSuburbs != 0) revert CityOrSuburbNotEmpty();

        // clear the empty City and decrement City counter
        // nested suburbs mapping will not be cleared, but we know it is empty
        delete cities[cityId];
        numberOfCities--;
    }

    /**
     * @dev If and only if a Suburb is EMPTY, it can be removed with this.
     *  All sales must be closed and no tokens can have been minted from this
     *  Suburb.
     *
     *  Intended for accidentally added suburbs (e.g. multiple/stuck txs).
     *
     *  User must confirm the cityId and suburbId as a sanity check, even
     *  though they must be the most recently constructed City and Suburb.
     *
     * @param cityId the City where the Suburb is located. Must be the most
     *  recently constructed City.
     * @param suburbId the Suburb ID to remove. Must be the most recently
     *  constructed Suburb.
     */
    function removeSuburb(uint256 cityId, uint256 suburbId)
        external
        onlyRole(SUPPORT_ROLE)
    {
        // revert if not the most recent City
        if (cityId != numberOfCities || cityId == 0) {
            revert NotTheMostRecentCity();
        }

        City storage c = cities[cityId];

        // revert if not the most recent Suburb in the City
        if (suburbId != c.numberOfSuburbs || suburbId == 0) {
            revert NotTheMostRecentSuburb();
        }

        Suburb storage s = c.suburbs[suburbId];

        // revert if any tokens have been sold
        if (s.currentSupply != 0) revert CityOrSuburbNotEmpty();

        // revert if any sales are active
        _revertIfAnySaleActive(s);

        // revert if any auctions are active
        _revertIfAnyAuctionActive(s);

        // reset token range in City
        if (suburbId > 1) {
            c.maxTokenId -= s.maxSupply;
        } else {
            c.maxTokenId = c.minTokenId; // as if City was newly initialized
        }

        // clear the Suburb and decrement counter
        delete c.suburbs[suburbId];
        c.numberOfSuburbs--;
    }

    /**************************************************************************
     * CITY ACCESS - get information about a City/Suburb
     */

    /**
     * @notice return the cityId a token belongs to. Does not check if token
     *  exists.
     * @param tokenId the token to search for
     * @return cityId the City containing tokenId
     */
    function getCityId(uint256 tokenId) public view returns (uint256) {
        if (tokenId == 0) revert InvalidTokenId();

        for (uint256 cityId = 1; cityId <= numberOfCities; ) {
            if (cities[cityId].maxTokenId >= tokenId) {
                return cityId;
            }
            unchecked {
                ++cityId;
            }
        }
        // should only revert if tokenId is out of range
        revert CityNotFound();
    }

    /**
     * @notice get structured data for a Suburb.
     *  Refer to Suburb struct layout for field ordering in returned tuple.
     * @param cityId the City containing suburbId
     * @param suburbId the suburbId within cityId
     * @return Suburb structured data for the Suburb
     */
    function suburbs(uint256 cityId, uint256 suburbId)
        public
        view
        returns (Suburb memory)
    {
        return cities[cityId].suburbs[suburbId];
    }

    /**************************************************************************
     * CITY ADMIN
     */

    /**
     * @dev set the merkle root to govern all allow lists. Reset this for each 
        new allow list sale.
     * @param merkleRoot_ the new merkle root
     */
    function setAllowList(bytes32 merkleRoot_) external onlyRole(SUPPORT_ROLE) {
        _setAllowList(merkleRoot_);
    }

    /**
     * @dev start and stop the allow list sale for a Suburb.
     *   Can be active at the same time as a public sale.
     *   Cannot be active at the same time as an English or Dutch auction.
     * @param cityId the parent City of the Suburb with the allowlist
     * @param suburbId the Suburb hosting the allow list
     * @param allowListState "true" starts the sale, "false" stops the sale
     */
    function setAllowListActive(
        uint256 cityId,
        uint256 suburbId,
        bool allowListState
    )
        external
        onlyRole(SUPPORT_ROLE)
    {
        _revertIfCityIdOrSuburbIdInvalid(cityId, suburbId);
        Suburb storage s = cities[cityId].suburbs[suburbId];

        _revertIfAnyAuctionActive(s);

        s.allowListActive = allowListState;
    }

    /**
     * @notice sets the base uri for a City
     * @dev this baseURI applies to all suburbs in a City
     * @param cityId identifier for the City
     * @param baseURI_ the base uri for the City
     */
    function setBaseURI(uint256 cityId, string memory baseURI_)
        external
        onlyRole(SUPPORT_ROLE)
    {
        if (cityId == 0 || cityId > numberOfCities) revert InvalidCityId();
        cities[cityId].baseURIExtended = baseURI_;
    }

    /**
     * @notice sets the base uri for ALL tokens, overriding City baseURIs.
     * @dev set this to override all the existing City-level baseURIs. The URI
     *  set here must include all tokens in the collection.
     *  To revert back to City-level baseURIs, set this to an empty string ("")
     * @param baseURI_ the base uri for the whole collection
     */
    function setBaseURIOverride(string memory baseURI_)
        external
        onlyRole(SUPPORT_ROLE)
    {
        _baseURIOverride = baseURI_;
    }

    /**
     * @dev start and stop the public sale for a Suburb.
     *   Can be active at the same time as an allow list sale.
     *   Cannot be active at the same time as an English or Dutch auction.
     * @param cityId the parent City of the Suburb hosting the sale
     * @param suburbId the Suburb hosting the sale
     * @param saleState "true" starts the sale, "false" stops the sale
     */
    function setSaleActive(
        uint256 cityId,
        uint256 suburbId,
        bool saleState
    )
        external
        onlyRole(SUPPORT_ROLE)
    {
        _revertIfCityIdOrSuburbIdInvalid(cityId, suburbId);
        Suburb storage s = cities[cityId].suburbs[suburbId];

        _revertIfAnyAuctionActive(s);

        s.saleActive = saleState;
    }

    /**************************************************************************
     * DUTCH AUCTIONS - create and manage Dutch auctions
     */

    /**
     * @dev set up a Dutch auction for a Suburb.
     *  This does not start the auction.
     *  This will replace any existing auction details for this Suburb.
     *  This cannot be called while a Dutch auction is active.
     *
     *  The auction duration is computed from the start price, final price,
     *  price step and time step. Before starting the auction, check the
     *  duration is correct by calling
     *  getDutchAuctionInfo(dutchAuctionId)
     *
     * @param cityId the parent City of the Suburb hosting the Dutch Auction
     * @param suburbId the Suburb to host the Dutch auction
     * @param startPriceInWei start price for the auction, in wei.
     * @param finalPriceInWei final price in wei. Lower than startPriceInWei.
     * @param priceStepInWei price decreases this amount of wei each time step.
     * @param timeStepInSeconds time between price decrease steps, in seconds.
     * @return dutchAuctionId the ID number associated with this auction.
     */
    function createNewDutchAuction(
        uint256 cityId,
        uint256 suburbId,
        uint88 startPriceInWei,
        uint88 finalPriceInWei,
        uint88 priceStepInWei,
        uint80 timeStepInSeconds
    )
        external
        onlyRole(SUPPORT_ROLE)
        returns (uint256)
    {
        _revertIfCityIdOrSuburbIdInvalid(cityId, suburbId);
        Suburb storage s = cities[cityId].suburbs[suburbId];

        _revertIfAnyAuctionActive(s);

        // create the auction, see {DutchAuctionHouse}
        uint256 dutchAuctionID_ = _createNewDutchAuction(
            startPriceInWei,
            finalPriceInWei,
            priceStepInWei,
            timeStepInSeconds
        );

        // store the auction ID
        s.dutchAuctionId = dutchAuctionID_;

        emit DutchAuctionCreatedInSuburb(cityId, suburbId, dutchAuctionID_);
        return dutchAuctionID_;
    }

    /**
     * @notice start a Dutch auction
     * @dev starts the most recently created Dutch auction in a Suburb.
     *  If called on an auction which has been ended, this restarts the auction,
     *  resetting price and timers.
     *
     *  Before starting the Dutch auction, check the parameters are correct by
     *  calling getDutchAuctionInfo(dutchAuctionId)
     *
     * @param cityId parent City of the auctioning Suburb
     * @param suburbId the Suburb hosting the Dutch auction
     */
    function startDutchAuction(uint256 cityId, uint256 suburbId)
        external
        onlyRole(SUPPORT_ROLE)
    {
        Suburb storage s = cities[cityId].suburbs[suburbId];

        _revertIfAnySaleActive(s);
        _revertIfAnyAuctionActive(s);

        _startDutchAuction(s.dutchAuctionId);
    }

    /**
     * @dev resume a stopped auction without resetting price and time counters
     * @param cityId parent City of the auctioning Suburb
     * @param suburbId the Suburb hosting the Dutch auction
     */
    function resumeDutchAuction(uint256 cityId, uint256 suburbId)
        external
        onlyRole(SUPPORT_ROLE)
    {
        Suburb storage s = cities[cityId].suburbs[suburbId];

        _revertIfAnySaleActive(s);
        _revertIfAnyAuctionActive(s);

        _resumeDutchAuction(s.dutchAuctionId);
    }

    /**
     * @dev end a Dutch auction
     * @param cityId parent City of the auctioning Suburb
     * @param suburbId the Suburb hosting the Dutch auction
     */
    function endDutchAuction(uint256 cityId, uint256 suburbId)
        external
        onlyRole(SUPPORT_ROLE)
    {
        uint256 auctionId = cities[cityId].suburbs[suburbId].dutchAuctionId;
        _endDutchAuction(auctionId);
    }

    /**
     * @notice get the current Dutch auction id in a Suburb. Use this in
     *  helper functions for Dutch auctions. Returns 0 if an invalid City or
     *  Suburb is requested.
     * @param cityId parent City of the auctioning Suburb
     * @param suburbId the Suburb to query
     * @return dutchAuctionId identifier for the current Dutch auction
     */
    function getDutchAuctionId(uint256 cityId, uint256 suburbId)
        external
        view
        returns (uint256)
    {
        return cities[cityId].suburbs[suburbId].dutchAuctionId;
    }

    /**
     * @dev set the maximum number of mints per wallet per Dutch Auction
     * @param maxMints maximum mints per wallet per Dutch Auction
     */
    function setMaxDutchAuctionMints(uint256 maxMints)
        external
        onlyRole(SUPPORT_ROLE)
    {
        maxDutchAuctionMints = maxMints;
    }

    /**************************************************************************
     * ENGLISH AUCTIONS - create and manage English auctions
     */

    /**
     * @dev set up a new English Auction (ascending price auction). This does
     *  NOT start the auction.
     *
     * Start time and duration are set when auction is started with
     *  startEnglishAuction().
     *
     * outbidBuffer is to prevent 1 wei increments on the winning bid, and is
     *  the minimum buffer new bids must exceed the current highest by.
     *
     * This will overwrite any unstarted English auctions in this Suburb.
     *
     * If any English auctions have been started in this Suburb, they must
     *  be ended and settled before creating a new one.
     *
     * @param cityId parent City of the auctioning Suburb
     * @param suburbId Suburb to host the English Auction
     * @param lotSize_ number of tokens to be sold in one bundle in this auction
     * @param startingBidInWei_ starting bid in wei for the auction
     * @param outbidBufferInWei_ new bids must exceed current highest by this
     * @return auctionId id for the new English Auction
     */
    function createNewEnglishAuction(
        uint256 cityId,
        uint256 suburbId,
        uint256 lotSize_,
        uint256 startingBidInWei_,
        uint256 outbidBufferInWei_
    )
        external
        onlyRole(SUPPORT_ROLE)
        returns (uint256)
    {
        _revertIfCityIdOrSuburbIdInvalid(cityId, suburbId);
        if (lotSize_ == 0) revert InvalidInputZeroSupply();
        Suburb storage s = cities[cityId].suburbs[suburbId];

        // English Auction sale check, included in _revertIfAnyAuctionActive()
        // cases:
        //  ea not started >> continue >> overwrite the old one
        //  ea started >> revert
        //  ea ended && !settled >> revert
        //  ea ended && settled >> continue >> overwrite the old one

        _revertIfAnyAuctionActive(s);

        // check there is supply available in this Suburb
        if (s.currentSupply + lotSize_ > s.maxSupply) {
            revert ExceedsSuburbMaximumSupply();
        }

        // set up the English Auction
        uint256 newEnglishId = _setUpEnglishAuction(
            lotSize_,
            startingBidInWei_,
            outbidBufferInWei_
        );

        s.englishAuctionId = newEnglishId;
        emit EnglishAuctionCreatedInSuburb(cityId, suburbId, newEnglishId);
        return newEnglishId;
    }

    /**
     * @dev start an English Auction which has already been set up. It can be
     *  started immediately, or some time in the future. When this has been
     *  called, no other sales can be started until this English Auction ends
     *  or is force-stopped.
     * @param cityId parent City of the auctioning Suburb
     * @param suburbId Suburb hosting the English Auction
     * @param startDelayInSeconds set 0 to start immediately, or delay the start
     * @param durationInSeconds the number of seconds the auction will run for
     */
    function startEnglishAuction(
        uint256 cityId,
        uint256 suburbId,
        uint256 startDelayInSeconds,
        uint256 durationInSeconds
    )
        external
        onlyRole(SUPPORT_ROLE)
    {
        Suburb storage s = cities[cityId].suburbs[suburbId];

        // check all sales are inactive for this Suburb, before starting
        _revertIfAnySaleActive(s);
        _revertIfAnyAuctionActive(s);

        // recheck there is supply available for the lot size
        uint256 auctionId = s.englishAuctionId;
        if (
            s.currentSupply + _englishAuctions[auctionId].lotSize > s.maxSupply
        ) {
            revert ExceedsSuburbMaximumSupply();
        }

        _startEnglishAuction(auctionId, startDelayInSeconds, durationInSeconds);
    }

    /**
     * @dev marks an English Auction as settled and mints the winner's token(s)
     * @param cityId parent City of the auctioning Suburb
     * @param suburbId the Suburb hosting the English Auction
     */
    function settleEnglishAuction(uint256 cityId, uint256 suburbId)
        external
    {
        Suburb storage s = cities[cityId].suburbs[suburbId];
        uint256 auctionId = s.englishAuctionId;

        // auction ended/settled checks done in _markSettled()
        _markSettled(auctionId);

        // mint token to the winner
        address winner = _englishAuctions[auctionId].highestBidder;

        if (winner != address(0)) {
            uint256 numberOfTokens_ = _englishAuctions[auctionId].lotSize;

            // to prevent _safeMint() reverting maliciously and sticking the
            // contract, we do not check onERC721Received(). Contracts bidding
            // in this English Auction do so at their own risk and should
            // ensure they can use their tokens once received, e.g. using
            // {IERC721-safeTransferFrom}
            _mintInSuburb(s, winner, numberOfTokens_);
        }
    }

    /**
     * @dev force stop an English Auction, returns ETH to highest bidder,
     *  the token is not sold.
     *  Cannot do this within the final 2 hours of an auction.
     * @param cityId parent City of the auctioning Suburb
     * @param suburbId the Suburb hosting the English Auction
     */
    function forceStopEnglishAuction(uint256 cityId, uint256 suburbId)
        external
        onlyRole(SUPPORT_ROLE)
        nonReentrant
    {
        Suburb storage s = cities[cityId].suburbs[suburbId];

        uint256 auctionId = s.englishAuctionId;
        _forceStopEnglishAuction(auctionId);
    }

    /**
     * @notice get the current englishAuctionId in a Suburb. Use this in
     *  helper functions for English auctions.
     * @param cityId parent City of the auctioning Suburb
     * @param suburbId the Suburb to query
     * @return englishAuctionId identifier for the active English Auction
     */
    function getEnglishAuctionId(uint256 cityId, uint256 suburbId)
        external
        view
        returns (uint256)
    {
        return cities[cityId].suburbs[suburbId].englishAuctionId;
    }

    /**
     * @dev edit the maximum gas sent with refunds during an English Auction.
     *  Gas limit initialized to 2300, but modifiable in case of future need.
     *
     *  Refunds are sent when:
     *  i) a high-bidder is outbid (their bid is returned)
     *  ii) an English Auction is force-stopped (current leader is refunded)
     *
     *  If this is set too low, all refunds using _gasLimitedCall() will
     *  fail.
     * @param maxGas maximum gas units for the call
     */
    function editMaxRefundGas(uint256 maxGas) external onlyRole(SUPPORT_ROLE) {
        _editMaxRefundGas(maxGas);
    }

    /**************************************************************************
     * MINT FUNCTIONS - mint tokens using each sale type
     */

    /**
     * @notice mint tokens from a City-Suburb on the public sale.
     * @param cityId the City ID to mint from
     * @param suburbId the Suburb ID within cityId to mint from: 1, 2, 3...
     * @param numberOfTokens number of tokens to mint
     */
    function mint(
        uint256 cityId,
        uint256 suburbId,
        uint256 numberOfTokens
    )
        external
        payable
    {
        Suburb storage s = cities[cityId].suburbs[suburbId];

        // check saleActive
        if (!s.saleActive) revert PublicSaleIsNotActive();

        // check sent value is correct
        uint256 price = s.pricePerToken;
        if (msg.value != price * numberOfTokens) revert WrongETHValueSent();

        _safeMintInSuburb(s, msg.sender, numberOfTokens);
    }

    /**
     * @notice mint tokens on the Allow List
     * @dev using {MerkleFourParams} to manage a multiparameter merkle tree
     * @param cityId the parent City of the Suburb to mint in
     * @param suburbId the Suburb to mint in
     * @param numberOfTokens how many tokens to mint
     * @param tokenQuotaInSuburb the total quota for this address in this
     *  Suburb, regardless of the number minted so far
     * @param merkleProof merkle proof for this address and Suburb combo
     */
    function mintAllowList(
        uint256 cityId,
        uint256 suburbId,
        uint256 numberOfTokens,
        uint256 tokenQuotaInSuburb,
        bytes32[] calldata merkleProof
    )
        external
        payable
    {
        Suburb storage s = cities[cityId].suburbs[suburbId];
        if (!s.allowListActive) revert AllowListIsNotActive();

        // check minted quota
        uint256 claimed_ = getAllowListMinted(msg.sender, cityId, suburbId);
        if (claimed_ + numberOfTokens > tokenQuotaInSuburb) {
            revert ExceedsAllowListQuota();
        }

        // check user is on allowlist and has their tokenQuotaInSuburb
        if (
            !onAllowList(
                msg.sender,
                tokenQuotaInSuburb,
                cityId,
                suburbId,
                merkleProof
            )
        ) {
            revert NotOnAllowList();
        }

        // check the eth passed is correct for this Suburb
        if (msg.value != numberOfTokens * s.allowListPricePerToken) {
            revert WrongETHValueSent();
        }

        // update allowlist minted for user
        _setAllowListMinted(msg.sender, cityId, suburbId, numberOfTokens);

        _safeMintInSuburb(s, msg.sender, numberOfTokens);
    }

    /**
     * @notice Mint tokens in the Dutch auction for any tier
     * @param cityId parent City of the auctioning Suburb
     * @param suburbId the Suburb hosting the Dutch auction
     * @param numberOfTokens The number of tokens to mint
     */
    function mintDutch(
        uint256 cityId,
        uint256 suburbId,
        uint256 numberOfTokens
    )
        external
        payable
        nonReentrant
    {
        Suburb storage s = cities[cityId].suburbs[suburbId];
        uint256 auctionId = s.dutchAuctionId;
        DutchAuction storage da = _dutchAuctions[auctionId];

        // check auction is active - see {DutchAuctionHouse}
        if (!da.auctionActive) revert DutchAuctionIsNotActive();

        // check current price
        uint256 tokenPrice = getDutchAuctionPrice(auctionId);
        uint256 salePrice = tokenPrice * numberOfTokens;
        if (msg.value < salePrice) revert WrongETHValueSent();

        // limit mints during price decline, unlimited at resting price
        if (tokenPrice > da.finalPrice) {
            if (
                (getDutchAuctionMints(auctionId, msg.sender) + numberOfTokens) >
                maxDutchAuctionMints
            ) {
                revert ExceedsMaximumTokensDuringDutchAuction();
            }
            // if resting price is already hit, this SSTORE is not needed
            _incrementDutchAuctionMints(auctionId, msg.sender, numberOfTokens);
        }

        _safeMintInSuburb(s, msg.sender, numberOfTokens);

        // refund if price declined before tx confirmed
        if (msg.value > salePrice) {
            uint256 refund = msg.value - salePrice;
            (bool success, ) = payable(msg.sender).call{value: refund}("");
            if (!success) revert RefundFailed();
        }
    }

    /**
     * @notice Bid on an English Auction for a Suburb. If you are the highest
     *  bidder already, extra bids are added to your current bid. All bids are
     *  final and cannot be revoked.
     *
     * NOTE: if bidding from a contract ensure it can use any tokens received.
     *  This does not check onERC721Received().
     *
     * @dev refunds previous highest bidder when new highest bid received.
     * @param cityId parent City of the auctioning Suburb
     * @param suburbId Suburb hosting the auction
     */
    function bidEnglish(uint256 cityId, uint256 suburbId)
        external
        payable
        nonReentrant
    {
        uint256 auctionId = cities[cityId].suburbs[suburbId].englishAuctionId;
        _bidEnglish(auctionId);
    }

    /**
     * @dev mint reserve tokens to any address
     * @param cityId the City ID to mint from
     * @param suburbId the Suburb ID within cityId to mint from: 1, 2, 3...
     * @param to recipient address
     * @param numberOfTokens number of tokens to mint
     */
    function devMint(
        uint256 cityId,
        uint256 suburbId,
        address to,
        uint256 numberOfTokens
    )
        external
        onlyRole(SUPPORT_ROLE)
    {
        _revertIfCityIdOrSuburbIdInvalid(cityId, suburbId);
        Suburb storage s = cities[cityId].suburbs[suburbId];
        _revertIfAnyAuctionActive(s);

        _safeMintInSuburb(s, to, numberOfTokens);
    }

    /**************************************************************************
     * OWNER FUNCTIONS
     */

    /**
     * @dev withdraws ether from the contract to the shareholder address
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 bal = address(this).balance;
        (bool success, ) = shareholderAddress.call{value: bal}("");

        if (!success) revert WithdrawFailed();
    }

    /**************************************************************************
     * INTERNAL MINT FUNCTIONS
     */

    /**
     * @dev internal mint helper - check and update supply, then return the
     *  next sequential ID to mint in the Suburb.
     * @param s the Suburb to mint in
     * @param quantity number of tokens to mint
     * @return nextId the next sequential ID to mint in the Suburb
     */
    function _mintChecksEffectsNextId(Suburb storage s, uint256 quantity)
        internal
        returns (uint256)
    {
        if (quantity == 0) revert ZeroQuantityRequested();

        // current supply check
        uint256 currentSupply_ = s.currentSupply;
        if (currentSupply_ + quantity > s.maxSupply) {
            revert ExceedsSuburbMaximumSupply();
        }

        // effects
        s.currentSupply = currentSupply_ + quantity;
        totalSupply += quantity;

        // return
        uint256 nextId = s.firstTokenId + currentSupply_;
        return nextId;
    }

    /**
     * @dev internal mint function using {ERC721-_mint} i.e. NOT checking
     *  {ERC721-onERC721Received}.
     * @param s the Suburb to mint in
     * @param receiver mint to this address
     * @param quantity number of tokens to mint
     */
    function _mintInSuburb(
        Suburb storage s,
        address receiver,
        uint256 quantity
    )
        internal
    {
        uint256 nextId = _mintChecksEffectsNextId(s, quantity);

        for (uint256 i; i < quantity; ) {
            _mint(receiver, nextId + i);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev internal mint function using {ERC721-_safeMint}
     * @param s the Suburb to mint in
     * @param receiver mint to this address
     * @param quantity number of tokens to mint
     */
    function _safeMintInSuburb(
        Suburb storage s,
        address receiver,
        uint256 quantity
    )
        internal
    {
        uint256 nextId = _mintChecksEffectsNextId(s, quantity);

        for (uint256 i; i < quantity; ) {
            _safeMint(receiver, nextId + i);
            unchecked {
                ++i;
            }
        }
    }

    /**************************************************************************
     * OVERRIDE SUPERS
     */

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(WCNFTToken, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev each City has its own baseURI.
     * Adapted from {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert InvalidTokenId();
        string memory baseURI = _baseURIOverride;

        if (bytes(baseURI).length == 0) {
            uint256 cityId = getCityId(tokenId);
            baseURI = cities[cityId].baseURIExtended;

            if (bytes(baseURI).length == 0) {
                return "";
            }
        }

        return string(abi.encodePacked(baseURI, Strings.toString(tokenId)));
    }

    /***************************************************************************
     * Operator Filter
     */

    function setApprovalForAll(address operator, bool approved)
        public
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId)
        public
        override
        onlyAllowedOperatorApproval(operator)
    {
        super.approve(operator, tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
