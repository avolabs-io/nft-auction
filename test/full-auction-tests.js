const { expect } = require("chai");

const { BigNumber } = require("ethers");
const { network } = require("hardhat");

const tokenId = 1;
const minPrice = 10000;

// Deploy and create a mock erc721 contract.
// Test end to end auction
describe("End to end auction tests", function () {
  let ERC721;
  let erc721;
  let NFTAuction;
  let nftAuction;
  let contractOwner;
  let user1;
  let user2;
  let user3;
  let user4;
  let bidIncreasePercentage;
  let auctionBidPeriod;
  //deploy mock erc721 token
  beforeEach(async function () {
    ERC721 = await ethers.getContractFactory("ERC721MockContract");
    NFTAuction = await ethers.getContractFactory("NFTAuction");
    [ContractOwner, user1, user2, user3, user4] = await ethers.getSigners();

    erc721 = await ERC721.deploy("my mockables", "MBA");
    await erc721.deployed();
    await erc721.mint(user1.address, 1);

    nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();
    //approve our smart contract to transfer this NFT
    await erc721.connect(user1).approve(nftAuction.address, 1);
  });
  describe("default auction end to end", async function () {
    bidIncreasePercentage = 10;
    auctionBidPeriod = 86400;
    beforeEach(async function () {
      await nftAuction
        .connect(user1)
        .createDefaultNftAuction(erc721.address, tokenId, minPrice);
    });
    it("should allow multiple bids and conclude auction after end period", async function () {
      nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
        value: minPrice,
      });
      const bidIncreaseByMinPercentage =
        (minPrice * (100 + bidIncreasePercentage)) / 100;
      await network.provider.send("evm_increaseTime", [auctionBidPeriod / 2]);
      await nftAuction.connect(user3).makeBid(erc721.address, tokenId, {
        value: bidIncreaseByMinPercentage,
      });
      await network.provider.send("evm_increaseTime", [86000]);
      const bidIncreaseByMinPercentage2 =
        (bidIncreaseByMinPercentage * (100 + bidIncreasePercentage)) / 100;
      await nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
        value: bidIncreaseByMinPercentage2,
      });
      await network.provider.send("evm_increaseTime", [86001]);
      const bidIncreaseByMinPercentage3 =
        (bidIncreaseByMinPercentage2 * (100 + bidIncreasePercentage)) / 100;
      await nftAuction.connect(user3).makeBid(erc721.address, tokenId, {
        value: bidIncreaseByMinPercentage3,
      });
      //should not be able to settle auction yet
      await expect(
        nftAuction.connect(user3).settleAuction(erc721.address, tokenId)
      ).to.be.revertedWith("Auction is not yet over");
      await network.provider.send("evm_increaseTime", [auctionBidPeriod + 1]);
      //auction has ended
      await nftAuction.connect(user3).settleAuction(erc721.address, tokenId);
      expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);
    });
  });
  describe("Custom auction end to end", async function () {
    bidIncreasePercentage = 20;
    auctionBidPeriod = 106400;
    beforeEach(async function () {
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
    it("should allow multiple bids and conclude auction after end period", async function () {
      nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
        value: minPrice,
      });
      const bidIncreaseByMinPercentage =
        (minPrice * (100 + bidIncreasePercentage)) / 100;
      await network.provider.send("evm_increaseTime", [43200]);
      await nftAuction.connect(user3).makeBid(erc721.address, tokenId, {
        value: bidIncreaseByMinPercentage,
      });
      await network.provider.send("evm_increaseTime", [86000]);
      const bidIncreaseByMinPercentage2 =
        (bidIncreaseByMinPercentage * (100 + bidIncreasePercentage)) / 100;
      await nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
        value: bidIncreaseByMinPercentage2,
      });
      await network.provider.send("evm_increaseTime", [86001]);
      const bidIncreaseByMinPercentage3 =
        (bidIncreaseByMinPercentage2 * (100 + bidIncreasePercentage)) / 100;
      await nftAuction.connect(user3).makeBid(erc721.address, tokenId, {
        value: bidIncreaseByMinPercentage3,
      });
      //should not be able to settle auction yet
      await expect(
        nftAuction.connect(user3).settleAuction(erc721.address, tokenId)
      ).to.be.revertedWith("Auction is not yet over");
      await network.provider.send("evm_increaseTime", [auctionBidPeriod + 1]);
      //auction has ended
      await nftAuction.connect(user3).settleAuction(erc721.address, tokenId);
      expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);
    });
  });
  describe("Early bid auction end to end", async function () {
    bidIncreasePercentage = 20;
    auctionBidPeriod = 106400;
    beforeEach(async function () {
      await nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
        value: minPrice,
      });
    });
    it("should allow owner to create auction which concludes after multiple bids", async function () {
      await nftAuction
        .connect(user1)
        .createNewNftAuction(
          erc721.address,
          tokenId,
          minPrice,
          auctionBidPeriod,
          bidIncreasePercentage
        );

      await expect(
        nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
          value: minPrice,
        })
      ).to.be.revertedWith("Bid must be % more than previous highest bid");
      const bidIncreaseByMinPercentage =
        (minPrice * (100 + bidIncreasePercentage)) / 100;
      await network.provider.send("evm_increaseTime", [43200]);
      await nftAuction.connect(user3).makeBid(erc721.address, tokenId, {
        value: bidIncreaseByMinPercentage,
      });
      await network.provider.send("evm_increaseTime", [86000]);
      const bidIncreaseByMinPercentage2 =
        (bidIncreaseByMinPercentage * (100 + bidIncreasePercentage)) / 100;
      await nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
        value: bidIncreaseByMinPercentage2,
      });
      await network.provider.send("evm_increaseTime", [86001]);
      const bidIncreaseByMinPercentage3 =
        (bidIncreaseByMinPercentage2 * (100 + bidIncreasePercentage)) / 100;
      await nftAuction.connect(user3).makeBid(erc721.address, tokenId, {
        value: bidIncreaseByMinPercentage3,
      });
      //should not be able to settle auction yet
      await expect(
        nftAuction.connect(user3).settleAuction(erc721.address, tokenId)
      ).to.be.revertedWith("Auction is not yet over");
      await network.provider.send("evm_increaseTime", [auctionBidPeriod + 1]);
      //auction has ended
      await nftAuction.connect(user3).settleAuction(erc721.address, tokenId);
      expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);
    });
  });
  describe("Test custom bids on custom auction", async function () {
    bidIncreasePercentage = 20;
    auctionBidPeriod = 106400;
    beforeEach(async function () {
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
    it("should allow multiple custom bids and conclude auction after end period", async function () {
      nftAuction
        .connect(user2)
        .makeCustomBid(erc721.address, tokenId, user4.address, {
          value: minPrice,
        });
      const bidIncreaseByMinPercentage =
        (minPrice * (100 + bidIncreasePercentage)) / 100;
      await network.provider.send("evm_increaseTime", [43200]);
      await nftAuction.connect(user3).makeBid(erc721.address, tokenId, {
        value: bidIncreaseByMinPercentage,
      });
      await network.provider.send("evm_increaseTime", [86000]);
      const bidIncreaseByMinPercentage2 =
        (bidIncreaseByMinPercentage * (100 + bidIncreasePercentage)) / 100;
      await nftAuction
        .connect(user2)
        .makeCustomBid(erc721.address, tokenId, user4.address, {
          value: bidIncreaseByMinPercentage2,
        });
      await network.provider.send("evm_increaseTime", [86001]);
      const bidIncreaseByMinPercentage3 =
        (bidIncreaseByMinPercentage2 * (100 + bidIncreasePercentage)) / 100;
      await nftAuction
        .connect(user3)
        .makeCustomBid(erc721.address, tokenId, user4.address, {
          value: bidIncreaseByMinPercentage3,
        });
      //should not be able to settle auction yet
      await expect(
        nftAuction.connect(user3).settleAuction(erc721.address, tokenId)
      ).to.be.revertedWith("Auction is not yet over");
      await network.provider.send("evm_increaseTime", [auctionBidPeriod + 1]);
      //auction has ended
      await nftAuction.connect(user3).settleAuction(erc721.address, tokenId);
      expect(await erc721.ownerOf(tokenId)).to.equal(user4.address);
    });
  });
});
