const { expect } = require("chai");
const { ethers } = require("hardhat");

const { BigNumber } = require("ethers");
// Enable and inject BN dependency

const tokenId = 1;
const buyNowPrice = 100;
const newMinPrice = 50;
const tokenBidAmount = 250;
const tokenAmount = 500;
const auctionBidPeriod = 86400; //seconds
const bidIncreasePercentage = 10;
const zeroAddress = "0x0000000000000000000000000000000000000000";
const zeroERC20Tokens = 0;
const emptyFeeRecipients = [];
const emptyFeePercentages = [];

// Deploy and create a mock erc721 contract.

describe("ERC20 Whitelist Sale Tests", function () {
  let ERC721;
  let erc721;
  let ERC20;
  let erc20;
  let NFTAuction;
  let nftAuction;
  let contractOwner;
  let user1;
  let user2;
  let user3;

  beforeEach(async function () {
    ERC721 = await ethers.getContractFactory("ERC721MockContract");
    ERC20 = await ethers.getContractFactory("ERC20MockContract");
    NFTAuction = await ethers.getContractFactory("NFTAuction");
    [ContractOwner, user1, user2, user3] = await ethers.getSigners();

    erc721 = await ERC721.deploy("my mockables", "MBA");
    await erc721.deployed();
    await erc721.mint(user1.address, 1);

    erc20 = await ERC20.deploy("Mock ERC20", "MER");
    await erc20.deployed();

    await erc20.mint(user1.address, tokenAmount);
    await erc20.mint(user2.address, tokenAmount);
    await erc20.mint(user3.address, tokenAmount);

    nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();
    //approve our smart contract to transfer this NFT
    await erc721.connect(user1).approve(nftAuction.address, tokenId);
    await erc20.connect(user1).approve(nftAuction.address, tokenAmount);
    await erc20.connect(user2).approve(nftAuction.address, tokenBidAmount);
    await erc20.connect(user3).approve(nftAuction.address, tokenAmount);
  });
  describe("Create basic whitelist sale", async function () {
    beforeEach(async function () {
      await nftAuction.connect(user1).createSale(
        erc721.address,
        tokenId,
        erc20.address,
        buyNowPrice,
        user2.address, //whitelisted buyer
        emptyFeeRecipients,
        emptyFeePercentages
      );
    });
    // whitelisted buyer should be able to purchase NFT
    it("should allow whitelist buyer to purchase NFT", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, erc20.address, buyNowPrice);
      expect(await erc721.ownerOf(tokenId)).to.equal(user2.address);
      expect(await erc20.balanceOf(user1.address)).to.be.equal(
        BigNumber.from(tokenAmount + buyNowPrice).toString()
      );
    });
    it("should reset variable if sale successful", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, erc20.address, buyNowPrice);
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
      expect(result.ERC20Token).to.be.equal(zeroAddress);
    });
    it("should allow whitelist buyer to purchase NFT and add recipient", async function () {
      await nftAuction
        .connect(user2)
        .makeCustomBid(
          erc721.address,
          tokenId,
          erc20.address,
          buyNowPrice,
          user3.address
        );
      expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);
    });
    // non whitelisted buyer should not be able to purchase NFT
    it("should revert non whitelist buyer", async function () {
      await expect(
        nftAuction
          .connect(user3)
          .makeBid(erc721.address, tokenId, erc20.address, buyNowPrice)
      ).to.be.revertedWith("only the whitelisted buyer can bid on this NFT");
      expect(await erc721.ownerOf(tokenId)).to.equal(nftAuction.address);
    });
    //test buyer can't purchase nft below the minimum price
    it("should allow whitelist buyer to bid below sale price", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, erc20.address, buyNowPrice - 1);
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
          .makeBid(erc721.address, tokenId, erc20.address, buyNowPrice)
      ).to.be.revertedWith("only the whitelisted buyer can bid on this NFT");
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, erc20.address, buyNowPrice);
      expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);
    });
    it("should revert underbid if different whitelist buyer set", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, erc20.address, buyNowPrice - 1);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      await nftAuction
        .connect(user1)
        .updateWhitelistedBuyer(erc721.address, tokenId, user3.address);
      expect(await erc721.ownerOf(tokenId)).to.equal(nftAuction.address);
      result = await nftAuction.nftContractAuctions(erc721.address, tokenId);

      expect(result.buyNowPrice).to.be.not.equal(BigNumber.from(0).toString());
      expect(result.nftHighestBid.toString()).to.be.equal(
        BigNumber.from(0).toString()
      );
      expect(result.nftHighestBidder).to.be.equal(zeroAddress);
    });
    it("should not allow other users to update whitelisted buyer", async function () {
      await expect(
        nftAuction
          .connect(user2)
          .updateWhitelistedBuyer(erc721.address, tokenId, user3.address)
      ).to.be.revertedWith("Only the owner can call this function");
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
});
