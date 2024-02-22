// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../IWCNFTErrorCodes.sol";

contract EnglishAuctionHouse is IWCNFTErrorCodes {
    struct EnglishAuction {
        uint256 lotSize; // number of tokens to be sold
        uint256 highestBid; // current highest bid, in WEI
        uint256 outbidBuffer; // new bids must exceed highestBid by this, in WEI
        uint256 startTime; // unix timestamp in seconds at start of the auction
        uint256 endTime; // unix timestamp in seconds at the end of the auction
        address highestBidder; // current highest bidder
        bool settled; // flag to mark the auction as settled
    }

    uint256 public numberOfEnglishAuctions;
    uint256 private constant _MAXIMUM_START_DELAY = 1 weeks;
    uint256 private constant _EXTEND_PERIOD = 15 minutes;
    uint256 private constant _MAXIMUM_DURATION = 1 weeks;
    uint256 private constant _MINIMUM_DURATION = 1 hours;
    uint256 private constant _MINIMUM_TIME_BUFFER = 2 hours; // cannot stop auction within 2 hours of end
    uint256 private _maxRefundGas = 2300; // max gas sent with refunds
    mapping(uint256 => EnglishAuction) internal _englishAuctions;

    /**************************************************************************
     * CUSTOM ERRORS
     */

    /// Bid must exceed the current highest bid, plus buffer price
    error BidTooLow();

    /// Auctions cannot be stopped within 2 hours of their end time
    error CannotStopAuction();

    /// attempting to initialize an auction that is already initialized
    error EnglishAuctionAlreadyInitialized();

    /// requested English auction has ended
    error EnglishAuctionHasEnded();

    /// The requested English auction is not currently accepting bids
    error EnglishAuctionIsNotBiddable();

    /// The requested English auction is not ended and settled
    error EnglishAuctionIsNotComplete();

    /// The requested English auction has already been settled
    error EnglishAuctionIsSettled();

    /**
     * The requested English auction has not ended. It is not
     * necessarily active, as the start may be delayed
     */
    error EnglishAuctionNotEnded();

    /// Duration cannot exceed _MAXIMUM_DURATION
    error ExceedsMaximumDuration();

    /// Cannot start too far in the future
    error ExceedsMaximumStartDelay();

    /// Duration must exceed _MINIMUM_DURATION
    error InsufficientDuration();

    /// The requested EnglishAuction does not exist in this contract
    error InvalidEnglishAuctionId();

    /**************************************************************************
     * EVENTS
     */

    /**
     * @dev emitted when an English auction is created
     * @param auctionId identifier for the English auction
     * @param lotSize number of tokens sold in this auction
     * @param startingBid initial bid in wei
     */
    event EnglishAuctionCreated(
        uint256 indexed auctionId,
        uint256 lotSize,
        uint256 startingBid
    );

    /**
     * @dev emitted when an English auction is started
     * @param auctionId identifier for the English auction
     * @param auctionStartTime unix timestamp in seconds of the auction start
     * @param auctionEndTime unix timestamp in seconds of the auction end
     */
    event EnglishAuctionStarted(
        uint256 indexed auctionId,
        uint256 auctionStartTime,
        uint256 auctionEndTime
    );

    /**
     * @dev emitted when an auction is settled
     * @param auctionId identifier for the English auction
     * @param salePrice strike price for the lot
     * @param lotSize number of tokens sold in this auction
     * @param winner address of the winning bidder
     */
    event EnglishAuctionSettled(
        uint256 indexed auctionId,
        uint256 salePrice,
        uint256 lotSize,
        address winner
    );

    /**
     * @dev emitted when an auction is force-stopped
     * @param auctionId identifier for the English auction
     * @param currentHighBidder address of the current leading bidder
     * @param currentHighestBid value in wei of the current highest bid
     */
    event EnglishAuctionForceStopped(
        uint256 indexed auctionId,
        address currentHighBidder,
        uint256 currentHighestBid
    );

    /**
     * @dev emitted when a new high bid is received
     * @param auctionId identifier for the English auction
     * @param bidder address of the new high bidder
     * @param bid value in wei of the new bid
     */
    event NewHighBid(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 bid
    );

    /**
     * @dev emitted when an auto refund fails
     * @param auctionId identifier for the English auction
     * @param recipient address of the user whose refund has been lodged
     * @param amount amount in wei of the refund
     */
    event RefundLodged(
        uint256 indexed auctionId,
        address indexed recipient,
        uint256 amount
    );

    /**************************************************************************
     * GUARD FUNCTIONS - replace modifiers
     */

    /**
     * @dev reverts if a given English auction is not active
     * @param auctionId identifier for the English auction
     */
    function _revertIfEnglishAuctionNotValid(uint256 auctionId) internal view {
        if (auctionId == 0 || auctionId > numberOfEnglishAuctions) {
            revert InvalidEnglishAuctionId();
        }
    }

    /**************************************************************************
     * ADMIN FUNCTIONS - start, stop, edit, etc.
     */

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
    function _editMaxRefundGas(uint256 maxGas) internal {
        _maxRefundGas = maxGas;
    }

    /**
     * @dev set up a new English auction (ascending price auction). This does
     *  NOT start the auction.
     *
     * Start time and duration are set when auction is started with
     *  _startEnglishAuction().
     *
     * outbidBuffer is to prevent 1 wei increments on the winning bid, and is
     *  the minimum buffer new bids must exceed the current highest by.
     *
     * @param lotSize_ number of tokens to be sold in one bundle in this auction
     * @param startingBidInWei starting bid for the auction
     * @param outbidBufferInWei bids must exceed current highest by this price
     * @return auctionId sequential auction identifier, starting at 1.
     */
    function _setUpEnglishAuction(
        uint256 lotSize_,
        uint256 startingBidInWei,
        uint256 outbidBufferInWei
    )
        internal
        returns (uint256)
    {
        // set up new auction - auctionId initializes to 1
        uint256 auctionId = ++numberOfEnglishAuctions;

        EnglishAuction storage ea = _englishAuctions[auctionId];
        ea.lotSize = lotSize_;
        ea.highestBid = startingBidInWei;
        ea.outbidBuffer = outbidBufferInWei;

        emit EnglishAuctionCreated(auctionId, lotSize_, startingBidInWei);

        return auctionId;
    }

    /**
     * @dev start an English auction which has been set up already.
     * @param auctionId the auction to start
     * @param startDelayInSeconds set 0 to start immediately, or delay the start
     * @param durationInSeconds the number of seconds the auction will run for
     */
    function _startEnglishAuction(
        uint256 auctionId,
        uint256 startDelayInSeconds,
        uint256 durationInSeconds
    )
        internal
    {
        _revertIfEnglishAuctionNotValid(auctionId);

        EnglishAuction storage ea = _englishAuctions[auctionId];

        // check the auction has not been initialized yet
        if (ea.startTime != 0 && ea.endTime != 0) {
            revert EnglishAuctionAlreadyInitialized();
        }

        if (startDelayInSeconds > _MAXIMUM_START_DELAY) {
            revert ExceedsMaximumStartDelay();
        }

        if (durationInSeconds < _MINIMUM_DURATION) {
            revert InsufficientDuration();
        }

        if (durationInSeconds > _MAXIMUM_DURATION) {
            revert ExceedsMaximumDuration();
        }

        // get the start time
        uint256 startTime_ = block.timestamp + startDelayInSeconds;
        uint256 endTime_ = startTime_ + durationInSeconds;

        ea.startTime = startTime_;
        ea.endTime = endTime_;

        emit EnglishAuctionStarted(auctionId, startTime_, endTime_);
    }

    /**
     * @dev force stop an English auction, useful if incorrect parameters
     *  were set by mistake. To protect bidders, this cannot be used within 2
     *  hours of an auction's end time.
     * @param auctionId identifier for the auction
     */
    function _forceStopEnglishAuction(uint256 auctionId) internal {
        _revertIfEnglishAuctionNotValid(auctionId);

        EnglishAuction storage ea = _englishAuctions[auctionId];

        // if the auction has started, check there is longer than 2 hours left
        if (ea.endTime != 0) {
            if (block.timestamp >= ea.endTime) {
                revert EnglishAuctionHasEnded();
            }
            if (block.timestamp > (ea.endTime - _MINIMUM_TIME_BUFFER)) {
                revert CannotStopAuction();
            }
        }

        // end the auction
        ea.endTime = block.timestamp;
        ea.settled = true;

        // return eth to highest bidder
        address currentHighBidder = ea.highestBidder;
        uint256 currentBid = ea.highestBid;
        ea.highestBid = 0;

        if (currentHighBidder != address(0)) {
            bool refundSuccess = _gasLimitedCall(currentHighBidder, currentBid);
            if (!refundSuccess) {
                // register the failed refund
                emit RefundLodged(auctionId, currentHighBidder, currentBid);
            }
        }

        emit EnglishAuctionForceStopped(
            auctionId,
            currentHighBidder,
            currentBid
        );
    }

    /**
     * @dev checks an auction has ended, then marks it as settled, emitting an
     *  event. Set this when all accounting has been completed to block multiple
     *  claims, e.g. the winner receives their token, all refunds are sent etc.
     * @param auctionId identifier for the auction
     */
    function _markSettled(uint256 auctionId) internal {
        _revertIfEnglishAuctionNotValid(auctionId);

        if (!_englishAuctionEnded(auctionId)) {
            revert EnglishAuctionNotEnded();
        }

        EnglishAuction storage ea = _englishAuctions[auctionId];

        if (ea.settled) revert EnglishAuctionIsSettled();
        ea.settled = true;

        emit EnglishAuctionSettled(
            auctionId,
            ea.highestBid,
            ea.lotSize,
            ea.highestBidder
        );
    }

    /**************************************************************************
     * ACCESS FUNCTIONS - get information
     */

    /**
     * @dev get structured information about an English auction. If all entries
     *  are zero or false, the auction with this ID may not have been created.
     * @param auctionId the auction id to query
     * @return EnglishAuction structured information about the auction,
     *  returned as a tuple.
     */
    function getEnglishAuctionInfo(uint256 auctionId)
        public
        view
        returns (EnglishAuction memory)
    {
        return _englishAuctions[auctionId];
    }

    /**
     * @notice get the minimum bid to become the highest bidder on
     *   an English auction. This does not check if auction is active or ended.
     * @param auctionId identifier for the auction
     * @return minimumBid minimum bid to become the highest bidder
     */
    function getEnglishAuctionMinimumBid(uint256 auctionId)
        public
        view
        returns (uint256)
    {
        _revertIfEnglishAuctionNotValid(auctionId);

        EnglishAuction storage ea = _englishAuctions[auctionId];
        return ea.highestBid + ea.outbidBuffer;
    }

    /**
     * @dev return the time remaining in an English auction.
     *  Does not check if the auction has been initialized and will
     *  return 0 if it does not exist.
     * @param auctionId the auctionId to query
     * @return remainingTime the time remaining in seconds
     */
    function getRemainingEnglishAuctionTime(uint256 auctionId)
        public
        view
        returns (uint256)
    {
        uint256 endTime_ = _englishAuctions[auctionId].endTime;
        uint256 remaining = endTime_ <= block.timestamp
            ? 0
            : endTime_ - block.timestamp;

        return remaining;
    }

    /**************************************************************************
     * OPERATION
     */

    /**
     * @notice bid on an English auction. If you are the highest bidder already
     *  extra bids are added to your current bid. All bids are final and cannot
     *  be revoked.
     *
     * NOTE: if bidding from a contract ensure it can use any tokens received.
     *  This does not check onERC721Received().
     *
     * @param auctionId identifier for the auction
     */
    function _bidEnglish(uint256 auctionId) internal {
        _revertIfEnglishAuctionNotValid(auctionId);

        if (!englishAuctionBiddable(auctionId)) {
            revert EnglishAuctionIsNotBiddable();
        }

        EnglishAuction storage ea = _englishAuctions[auctionId];

        uint256 currentBid = ea.highestBid;
        address currentHighBidder = ea.highestBidder;

        /*
         * high bidder can add to their bid,
         * new bidders must exceed existing high bid + buffer
         */
        if (msg.sender == currentHighBidder) {
            ea.highestBid = currentBid + msg.value;
            emit NewHighBid(auctionId, msg.sender, currentBid + msg.value);
        } else {
            // new bidder
            if (msg.value < currentBid + ea.outbidBuffer) {
                revert BidTooLow();
            } else {
                if ((block.timestamp - ea.endTime) < _EXTEND_PERIOD) {
                    if ((block.timestamp - ea.startTime) > _MAXIMUM_DURATION) {
                        revert ExceedsMaximumDuration();
                    }
                    // extend the auction by 15 minutes
                    ea.endTime = block.timestamp + _EXTEND_PERIOD;
                }
                // we have a new highest bid
                ea.highestBid = msg.value;
                ea.highestBidder = msg.sender;
                emit NewHighBid(auctionId, msg.sender, msg.value);


                // refund the previous highest bidder.
                // This must not revert due to the receiver.
                if (currentHighBidder != address(0)) {
                    bool refundSuccess = _gasLimitedCall(
                        currentHighBidder,
                        currentBid
                    );
                    if (!refundSuccess) {
                        // register the failed refund
                        emit RefundLodged(
                            auctionId,
                            currentHighBidder,
                            currentBid
                        );
                    }
                }
            }
        }
    }

    /**
     * @dev send ETH, limiting gas and not reverting on failure.
     * @param receiver transaction recipient
     * @param amount value to send
     * @return success true if transaction is successful, false otherwise
     */
    function _gasLimitedCall(address receiver, uint256 amount)
        internal
        returns (bool)
    {
        (bool success, ) = receiver.call{value: amount, gas: _maxRefundGas}("");
        return success;
    }

    /**************************************************************************
     * HELPERS
     */

    /**
     * @dev returns true if an auction has been 'started' but has not ended.
     *  The auction may be pending (start time has been set in the future) or
     *  live-and-biddable (start time has passed and the auction is biddable).
     * @param auctionId identifier for the auction
     * @return active true (active / pending) or false (ended / not initialized)
     */
    function englishAuctionActive(uint256 auctionId)
        public
        view
        returns (bool)
    {
        // if ea.endTime == 0 : auction has not been started >> false
        // if ea.endTime <= block.timestamp : auction has ended >> false
        // if ea.endTime > block.timestamp : auction is pending or live >> true

        return (_englishAuctions[auctionId].endTime > block.timestamp);
    }

    /**
     * @dev returns true if an auction is currently live-and-biddable
     * @param auctionId identifier for the auction
     * @return biddable true (live-and-biddable) or false (ended / not started)
     */
    function englishAuctionBiddable(uint256 auctionId)
        public
        view
        returns (bool)
    {
        EnglishAuction storage ea = _englishAuctions[auctionId];

        return (
            ea.startTime <= block.timestamp &&
            block.timestamp < ea.endTime
        );
    }

    /**
     * @dev returns true if the requested auction has been settled,
     *  false otherwise.
     * @param auctionId identifier for the auction
     */
    function englishAuctionSettled(uint256 auctionId)
        public
        view
        returns (bool)
    {
        return _englishAuctions[auctionId].settled;
    }

    /**
     * @dev returns true if an auction has ended, false if it is still active,
     *  or not initialized.
     * @param auctionId identifier for the auction
     * @return ended true (ended / non-existent) or false (active / yet-to-begin)
     */
    function _englishAuctionEnded(uint256 auctionId)
        internal
        view
        returns (bool)
    {
        EnglishAuction storage ea = _englishAuctions[auctionId];

        // if ea.endTime == 0 : auction never started / does not exist >> false
        // else :
        // if ea.endTime <= block.timestamp : auction has ended >> true
        // if ea.endTime > block.timestamp : auction still active >> false

        return (ea.endTime != 0 && ea.endTime <= block.timestamp);
    }

    /**
     * @dev returns true if the requested auction has been started but is NOT
     *  settled. It may have ended, or may still be biddable but it has not
     *  been settled. Returns false if auction has not started or if it has
     *  been ended and settled.
     * @param auctionId identifier for the auction
     */
    function _englishAuctionActiveNotSettled(uint256 auctionId)
        internal
        view
        returns (bool)
    {
        EnglishAuction storage ea = _englishAuctions[auctionId];

        // if ea.endTime == 0 : auction never started / does not exist >> false
        // else: (the auction has been started)
        // if the auction is active >> true
        // if the auction is ended-but-not-settled >> true
        // if the auction is ended-and-settled >> false
        // if the auction is settled, it must already have ended
        
        return (ea.endTime != 0 && ea.settled == false);
    }
}
