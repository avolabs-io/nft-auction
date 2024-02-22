// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @dev Allows derived contracts to implement multiple parallel Dutch auctions,
 *  where the auction price decreases in steps.
 */
contract DutchAuctionHouse {
    struct DutchAuction {
        bool auctionActive; // flag to mark the auction active or inactive
        uint80 startTime; // set automatically when auction started
        uint80 duration; // time for price to drop from startPrice to finalPrice
        uint88 startPrice; // price declines from here
        uint88 finalPrice; // price rests here after declining
        uint88 priceStep; // price declines in this step size
        uint80 timeStepSeconds; // time between price drop steps
    }

    uint256 public numberOfDutchAuctions; // track number of auctions

    // Map auctionId => DutchAuction
    mapping(uint256 => DutchAuction) internal _dutchAuctions;

    // Track user mints per Dutch auction:
    // (auctionId => (address => mints))
    mapping(uint256 => mapping(address => uint256)) private _dutchAuctionMints;

    /**************************************************************************
     * CUSTOM ERRORS
     */

    /// The price and timestep parameters result in too great a duration
    error ComputedDurationOverflows();

    /// Attempting to resume a Dutch auction that has not started
    error DutchAuctionHasNotStarted();

    /// Attempted access to an active Dutch auction
    error DutchAuctionIsActive();

    /// Attempted mint on an inactive Dutch auction
    error DutchAuctionIsNotActive();

    /// Ensure auction prices, price steps and step interval are valid
    error InvalidDutchAuctionParameters();

    /// This auctionId has not been initialised yet
    error NonExistentDutchAuctionID();

    /**************************************************************************
     * EVENTS
     */

    /**
     * @dev emitted when a Dutch auction is created
     * @param auctionId identifier for the Dutch auction
     */
    event DutchAuctionCreated(uint256 auctionId);

    /**
     * @dev emitted when a Dutch auction starts
     * @param auctionId identifier for the Dutch auction
     * @param auctionStartTime unix timestamp in seconds of the auction start
     * @param auctionDuration auction duration in seconds
     */
    event DutchAuctionStart(
        uint256 indexed auctionId,
        uint80 auctionStartTime,
        uint80 auctionDuration
    );

    /**
     * @dev emitted when a Dutch auction ends
     * @param auctionId identifier for the Dutch auction
     * @param auctionEndTime unix timestamp in seconds of the auction end
     */
    event DutchAuctionEnd(uint256 indexed auctionId, uint256 auctionEndTime);

    /**************************************************************************
     * GUARD FUNCTIONS
     */

    /**
     * @dev reverts when an non-existent Dutch auction is requested
     * @param auctionId Dutch auction ID to query
     */
    function _revertIfDutchAuctionDoesNotExist(uint256 auctionId)
        internal
        view
    {
        if (auctionId == 0 || auctionId > numberOfDutchAuctions) {
            revert NonExistentDutchAuctionID();
        }
    }

    /**************************************************************************
     * FUNCTIONS
     */

    /**
     * @dev get structured information about a Dutch auction, returned as tuple
     * @param auctionId the Dutch auctionId to query.
     * @return auctionInfo information about the Dutch auction, struct returned
     *  as a tuple. See {struct DutchAuction} for details.
     */
    function getDutchAuctionInfo(uint256 auctionId)
        public
        view
        returns (DutchAuction memory)
    {
        return _dutchAuctions[auctionId];
    }

    /**
     * @notice get the number of mints by a user in a Dutch auction
     * @param auctionId the auction to query
     * @param user the minter address to query
     */
    function getDutchAuctionMints(uint256 auctionId, address user)
        public
        view
        returns (uint256)
    {
        return _dutchAuctionMints[auctionId][user];
    }

    /**
     * @dev calculates the current Dutch auction price. If not begun, returns
     *  the start price.
     * @param auctionId Dutch auction ID to query.
     * @return price current price in wei
     */
    function getDutchAuctionPrice(uint256 auctionId)
        public
        view
        returns (uint256)
    {
        _revertIfDutchAuctionDoesNotExist(auctionId);

        DutchAuction storage a = _dutchAuctions[auctionId];
        uint256 elapsed = _getElapsedDutchAuctionTime(auctionId);

        if (elapsed >= a.duration) {
            return a.finalPrice;
        }

        // step function
        uint256 steps = elapsed / a.timeStepSeconds;
        uint256 auctionPriceDecrease = steps * a.priceStep;

        return a.startPrice - auctionPriceDecrease;
    }

    /**
     * @dev returns the remaining time until a Dutch auction's resting price is
     *  hit. If the sale has not started yet, the auction duration is returned.
     *
     * Returning "0" shows the price has reached its final value - the auction
     *  may still be biddable.
     *
     * Use _endDutchAuction() to stop the auction and prevent further bids.
     *
     * @param auctionId Dutch auction ID to query
     * @return remainingTime seconds until resting price is reached
     */
    function getRemainingDutchAuctionTime(uint256 auctionId)
        public
        view
        returns (uint256)
    {
        _revertIfDutchAuctionDoesNotExist(auctionId);

        DutchAuction storage a = _dutchAuctions[auctionId];

        if (a.startTime == 0) {
            // not started yet
            return a.duration;
        } else if (_getElapsedDutchAuctionTime(auctionId) >= a.duration) {
            // already at the resting price
            return 0;
        }

        return (a.startTime + a.duration) - block.timestamp;
    }

    /**
     * @notice check if the Dutch auction with ID auctionId is active
     * @param auctionId Dutch auction ID to query
     * @return bool true if the auction is active, false if not
     */
    function _checkDutchAuctionActive(uint256 auctionId)
        internal
        view
        returns (bool)
    {
        return _dutchAuctions[auctionId].auctionActive;
    }

    /**
     * @dev initialise a new Dutch auction and return its ID
     * @param startPrice_ starting price in wei
     * @param finalPrice_ final resting price in wei
     * @param priceStep_ incremental price decrease in wei
     * @param timeStepSeconds_ time between each price decrease in seconds
     * @return newAuctionId the new Dutch auction ID
     */
    function _createNewDutchAuction(
        uint88 startPrice_,
        uint88 finalPrice_,
        uint88 priceStep_,
        uint80 timeStepSeconds_
    ) internal returns (uint256) {
        if (
            startPrice_ < finalPrice_ ||
            (startPrice_ - finalPrice_) < priceStep_
        ) {
            revert InvalidDutchAuctionParameters();
        }

        uint256 newAuctionID = ++numberOfDutchAuctions; // start with ID 1

        // create and map a new DutchAuction
        DutchAuction storage newAuction = _dutchAuctions[newAuctionID];

        newAuction.startPrice = startPrice_;
        newAuction.finalPrice = finalPrice_;
        newAuction.priceStep = priceStep_;
        newAuction.timeStepSeconds = timeStepSeconds_;

        uint256 duration = Math.ceilDiv(
            (startPrice_ - finalPrice_),
            priceStep_
        ) * timeStepSeconds_;

        if (duration == 0) revert InvalidDutchAuctionParameters();
        if (duration > type(uint80).max) revert ComputedDurationOverflows();

        newAuction.duration = uint80(duration);

        emit DutchAuctionCreated(newAuctionID);
        return newAuctionID;
    }

    /**
     * @dev starts a Dutch auction and emits an event.
     *
     * If an auction has been ended with _endDutchAuction() this will reset the
     *  auction and start it again with all of its initial arguments.
     *
     * @param auctionId ID of the Dutch auction to start
     */
    function _startDutchAuction(uint256 auctionId) internal {
        _revertIfDutchAuctionDoesNotExist(auctionId);

        DutchAuction storage a = _dutchAuctions[auctionId];

        if (a.auctionActive) revert DutchAuctionIsActive();

        a.startTime = uint80(block.timestamp);
        a.auctionActive = true;

        emit DutchAuctionStart(auctionId, a.startTime, a.duration);
    }

    /**
     * @dev if a Dutch auction was paused using _endDutchAuction it can be
     *  resumed with this function. No time is added to the duration so all
     *  elapsed time during the pause is lost.
     *
     * To restart a stopped Dutch auction from the startPrice with its full
     * duration, use _startDutchAuction() again.
     *
     * @param auctionId ID of the Dutch auction to resume
     */
    function _resumeDutchAuction(uint256 auctionId) internal {
        _revertIfDutchAuctionDoesNotExist(auctionId);

        DutchAuction storage a = _dutchAuctions[auctionId];

        if (a.startTime == 0) revert DutchAuctionHasNotStarted();
        if (a.auctionActive) revert DutchAuctionIsActive();

        a.auctionActive = true; // resume the auction
        emit DutchAuctionStart(auctionId, a.startTime, a.duration);
    }

    /**
     * @dev ends a Dutch auction and emits an event
     * @param auctionId ID of the Dutch auction to end
     */
    function _endDutchAuction(uint256 auctionId) internal {
        _revertIfDutchAuctionDoesNotExist(auctionId);

        if (!_dutchAuctions[auctionId].auctionActive) {
            revert DutchAuctionIsNotActive();
        }

        _dutchAuctions[auctionId].auctionActive = false;
        emit DutchAuctionEnd(auctionId, block.timestamp);
    }

    /**
     * @dev returns the elapsed time since the start of a Dutch auction.
     *  Does NOT check if the auction exists.
     *  Returns 0 if the auction has not started or does not exist.
     * @param auctionId Dutch auction ID to query
     * @return elapsedTime elapsed seconds, or 0 if auction does not exist.
     */
    function _getElapsedDutchAuctionTime(uint256 auctionId)
        internal
        view
        returns (uint256)
    {
        uint256 startTime_ = _dutchAuctions[auctionId].startTime;
        return startTime_ > 0 ? block.timestamp - startTime_ : 0;
    }

    /**
     * @notice set the mints for a user on a Dutch auction
     * @param auctionId the auction counter to modify
     * @param user the minter address to set
     * @param quantity increment the counter by this many
     */
    function _incrementDutchAuctionMints(
        uint256 auctionId,
        address user,
        uint256 quantity
    ) internal {
        _dutchAuctionMints[auctionId][user] += quantity;
    }
}
