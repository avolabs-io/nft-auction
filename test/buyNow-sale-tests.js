const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

const { BigNumber } = require("ethers");
// Enable and inject BN dependency

const tokenId = 1;
const buyNowPrice = 10000;
const auctionBidPeriod = 86400; //seconds
const bidIncreasePercentage = 10;
const zeroAddress = "0x0000000000000000000000000000000000000000";
const emptyFeeRecipients = [];
const emptyFeePercentages = [];
const zeroERC20Tokens = 0;

// Deploy and create a mock erc721 contract.

describe("BuyNow Sale tests", function () {
  let ERC721;
  let erc721;
  let NFTAuction;
  let nftAuction;
  let contractOwner;
  let user1;
  let user2;
  let user3;
  let testArtist;
  let testPlatform;
  let feeRecipients;
  let feePercentages;

  beforeEach(async function () {
    ERC721 = await ethers.getContractFactory("ERC721MockContract");
    NFTAuction = await ethers.getContractFactory("NFTAuction");
    [ContractOwner, user1, user2, user3, testArtist, testPlatform] =
      await ethers.getSigners();
    feeRecipients = [testArtist.address, testPlatform.address];
    feePercentages = [1000, 100];
    erc721 = await ERC721.deploy("my mockables", "MBA");
    await erc721.deployed();
    await erc721.mint(user1.address, tokenId);

    nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();
    //approve our smart contract to transfer this NFT
    await erc721.connect(user1).approve(nftAuction.address, tokenId);
  });
  describe("Create basic sale", async function () {
    beforeEach(async function () {
      await nftAuction.connect(user1).createSale(
        erc721.address,
        tokenId,
        zeroAddress,
        buyNowPrice,
        zeroAddress, //whitelisted buyer
        emptyFeeRecipients,
        emptyFeePercentages
      );
    });
    // whitelisted buyer should be able to purchase NFT
    it("should allow whitelist buyer to purchase NFT", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, 0, {
          value: buyNowPrice,
        });
      expect(await erc721.ownerOf(tokenId)).to.equal(user2.address);
    });
    it("should reset variable if sale successful", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, 0, {
          value: buyNowPrice,
        });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.buyNowPrice.toString()).to.be.equal(
        BigNumber.from(0).toString()
      );
      expect(result.nftHighestBid.toString()).to.be.equal(
        BigNumber.from(0).toString()
      );
    });
    it("should allow user2 to purchase NFT and add recipient", async function () {
      await nftAuction
        .connect(user2)
        .makeCustomBid(erc721.address, tokenId, zeroAddress, 0, user3.address, {
          value: buyNowPrice,
        });
      expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);
    });
    // non whitelisted buyer should not be able to purchase NFT
    it("should allow user3 to purchase NFT and add recipient", async function () {
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, 0, {
          value: buyNowPrice,
        });
      expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);
    });
    //test buyer can't purchase nft below the minimum price
    it("should allow any buyer below sale price", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, 0, {
          value: buyNowPrice - 1,
        });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.buyNowPrice).to.be.not.equal(BigNumber.from(0).toString());
      expect(result.nftHighestBid.toString()).to.be.equal(
        BigNumber.from(buyNowPrice - 1).toString()
      );
      expect(result.nftHighestBidder).to.be.equal(user2.address);
    });
    it("should allow seller to update whitelisted buyer", async function () {
      await nftAuction
        .connect(user1)
        .updateWhitelistedBuyer(erc721.address, tokenId, user3.address);
      await expect(
        nftAuction
          .connect(user2)
          .makeBid(erc721.address, tokenId, zeroAddress, 0, {
            value: buyNowPrice,
          })
      ).to.be.revertedWith("Only the whitelisted buyer");
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, 0, {
          value: buyNowPrice,
        });
      expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);
    });
    it("should not allow other users to update whitelisted buyer", async function () {
      await expect(
        nftAuction
          .connect(user2)
          .updateWhitelistedBuyer(erc721.address, tokenId, user3.address)
      ).to.be.revertedWith("Only nft seller");
    });
    it("should not allow user to update min price for a sale", async function () {
      let newMinPrice = 15000;
      await expect(
        nftAuction
          .connect(user1)
          .updateMinimumPrice(erc721.address, tokenId, newMinPrice)
      ).to.be.revertedWith("Not applicable for a sale");
    });
  });
  describe("Create sale test with fees", function () {
    beforeEach(async function () {
      await nftAuction.connect(user1).createSale(
        erc721.address,
        tokenId,
        zeroAddress,
        buyNowPrice,
        zeroAddress, //whitelisted buyer
        feeRecipients,
        feePercentages
      );
    });
    it("should allow any buyer to purchase NFT", async function () {
      let user1BalanceBeforePayout = await user1.getBalance();
      let testPlatformBalanceBeforePayout = await testPlatform.getBalance();
      let testArtistBalanceBeforePayout = await testArtist.getBalance();
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, 0, {
          value: buyNowPrice,
        });
      let platformAmount = BigNumber.from(testPlatformBalanceBeforePayout).add(
        BigNumber.from((buyNowPrice * 100) / 10000)
      );
      let artistAmount = BigNumber.from(testArtistBalanceBeforePayout).add(
        BigNumber.from((buyNowPrice * 1000) / 10000)
      );

      let user1Amount = BigNumber.from(buyNowPrice)
        .sub(BigNumber.from((buyNowPrice * 100) / 10000))
        .sub(BigNumber.from((buyNowPrice * 1000) / 10000));
      user1Amount = user1Amount.add(BigNumber.from(user1BalanceBeforePayout));
      let platformBal = await testPlatform.getBalance();
      let artistBal = await testArtist.getBalance();
      let user1Bal = await user1.getBalance();
      expect(await erc721.ownerOf(tokenId)).to.equal(user2.address);
      await expect(BigNumber.from(platformBal).toString()).to.be.equal(
        platformAmount
      );
      await expect(BigNumber.from(artistBal).toString()).to.be.equal(
        artistAmount
      );
      await expect(BigNumber.from(user1Bal).toString()).to.be.equal(
        user1Amount
      );
    });
  });
  describe("Test early bids with sales", async function () {
    let underBid = buyNowPrice - 1000;
    let result;
    this.beforeEach(async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: underBid,
        });
    });
    it("should transfer nft to early bidder", async function () {
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: buyNowPrice,
        });
      await nftAuction.connect(user1).createSale(
        erc721.address,
        tokenId,
        zeroAddress,
        buyNowPrice,
        zeroAddress, //whitelisted buyer
        emptyFeeRecipients,
        emptyFeePercentages
      );

      expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);
    });
  });
});
