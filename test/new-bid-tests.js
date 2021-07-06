const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

const { BigNumber } = require("ethers");
// Enable and inject BN dependency

const tokenId = 1;
const minPrice = 100;
const auctionBidPeriod = 86400; //seconds
const bidIncreasePercentage = 10;

// Deploy and create a mock erc721 contract.

describe("NFTAuction Bids", function () {
  let ERC721;
  let erc721;
  let NFTAuction;
  let nftAuction;
  let contractOwner;
  let user1;
  let user2;
  let user3;

  beforeEach(async function () {
    ERC721 = await ethers.getContractFactory("ERC721MockContract");
    NFTAuction = await ethers.getContractFactory("NFTAuction");
    [ContractOwner, user1, user2, user3] = await ethers.getSigners();

    erc721 = await ERC721.deploy("my mockables", "MBA");
    await erc721.deployed();
    await erc721.mint(user1.address, 1);

    nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();
    //approve our smart contract to transfer this NFT
    await erc721.connect(user1).approve(nftAuction.address, 1);

    await nftAuction
      .connect(user1)
      .createNewNftAuction(
        erc721.address,
        tokenId,
        minPrice,
        auctionBidPeriod,
        bidIncreasePercentage
      );
  });
  // 1 basic test, NFT put up for auction can accept bids with ETH
  it("Calling makeBid to bid on new NFTAuction", async function () {
    await nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
      value: minPrice,
    });
    let result = await nftAuction.nftContractAuctions(erc721.address, tokenId);
    expect(result.nftHighestBidder).to.equal(user2.address);
    expect(result.nftHighestBid.toString()).to.be.equal(
      BigNumber.from(minPrice).toString()
    );
  });

  describe("Function: makeBid", () => {
    it(" should ensure owner cannot bid on own NFT", async () => {
      await expect(
        nftAuction.connect(user1).makeBid(erc721.address, tokenId, {
          value: minPrice,
        })
      ).to.be.revertedWith("Owner cannot bid on own NFT");
    });

    it("should not allow bid lower than minimum bid percentage", async function () {
      nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
        value: minPrice,
      });
      await expect(
        nftAuction.connect(user3).makeBid(erc721.address, tokenId, {
          value: (minPrice * 101) / 100,
        })
      ).to.be.revertedWith("Bid must be % more than previous highest bid");
    });

    it("should allow for new bid if higher than minimum percentage", async function () {
      await nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
        value: minPrice,
      });
      const bidIncreaseByMinPercentage = (minPrice * 110) / 100;
      await nftAuction.connect(user3).makeBid(erc721.address, tokenId, {
        value: bidIncreaseByMinPercentage,
      });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.nftHighestBidder).to.equal(user3.address);
      expect(result.nftHighestBid.toString()).to.be.equal(
        BigNumber.from(bidIncreaseByMinPercentage).toString()
      );
    });
    // test for full functionality of makeBid still needed
  });

  describe("Function: _updateAuctionEnd", () => {
    it.skip("[unfinished] if min bid made, updates auctionEnd by another auctionLength", async () => {
      assert(true);
    });

    it.skip("[unfinished] if min bid not made, updates __  ", async () => {
      assert(true);
    });
  });
});
