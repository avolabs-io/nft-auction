const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

const { BigNumber } = require("ethers");
// Enable and inject BN dependency

const tokenId = 1;
const minPrice = 10000;
const auctionBidPeriod = 86400; //seconds
const bidIncreasePercentage = 10;
const zeroAddress = "0x0000000000000000000000000000000000000000";
const emptyFeeRecipients = [];
const emptyFeePercentages = [];

// Deploy and create a mock erc721 contract.

describe("Whitelist sale tests", function () {
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
  describe("Create basic whitelist sale", async function () {
    beforeEach(async function () {
      await nftAuction.connect(user1).createWhiteListSale(
        erc721.address,
        tokenId,
        zeroAddress,
        minPrice,
        user2.address, //whitelisted buyer
        emptyFeeRecipients,
        emptyFeePercentages
      );
    });
    // whitelisted buyer should be able to purchase NFT
    it("should allow whitelist buyer to purchase NFT", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, 0, {
          value: minPrice,
        });
      expect(await erc721.ownerOf(tokenId)).to.equal(user2.address);
    });
    it("should reset variable if sale successful", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, 0, {
          value: minPrice,
        });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.minPrice.toString()).to.be.equal(
        BigNumber.from(0).toString()
      );
      expect(result.nftHighestBid.toString()).to.be.equal(
        BigNumber.from(0).toString()
      );
    });
    it("should allow whitelist buyer to purchase NFT and add recipient", async function () {
      await nftAuction
        .connect(user2)
        .makeCustomBid(erc721.address, tokenId, zeroAddress, 0, user3.address, {
          value: minPrice,
        });
      expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);
    });
    // non whitelisted buyer should not be able to purchase NFT
    it("should revert non whitelist buyer", async function () {
      await expect(
        nftAuction
          .connect(user3)
          .makeBid(erc721.address, tokenId, zeroAddress, 0, {
            value: minPrice,
          })
      ).to.be.revertedWith("only the whitelisted buyer can bid on this NFT");
      expect(await erc721.ownerOf(tokenId)).to.equal(nftAuction.address);
    });
    //test buyer can't purchase nft below the minimum price
    it("should revert whitelist buyer below sale price", async function () {
      await expect(
        nftAuction
          .connect(user2)
          .makeBid(erc721.address, tokenId, zeroAddress, 0, {
            value: minPrice - 1,
          })
      ).to.be.revertedWith("Bid must be higher than minimum bid");
    });
    it("should allow seller to update whitelisted buyer", async function () {
      await nftAuction
        .connect(user1)
        .updateWhitelistedBuyer(erc721.address, tokenId, user3.address);
      await expect(
        nftAuction
          .connect(user2)
          .makeBid(erc721.address, tokenId, zeroAddress, 0, {
            value: minPrice,
          })
      ).to.be.revertedWith("only the whitelisted buyer can bid on this NFT");
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, 0, {
          value: minPrice,
        });
      expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);
    });
    it("should not allow other users to update whitelisted buyer", async function () {
      await expect(
        nftAuction
          .connect(user2)
          .updateWhitelistedBuyer(erc721.address, tokenId, user3.address)
      ).to.be.revertedWith("Only the owner can call this function");
    });
  });
  describe("Create whitelist test with fees", function () {
    beforeEach(async function () {
      await nftAuction.connect(user1).createWhiteListSale(
        erc721.address,
        tokenId,
        zeroAddress,
        minPrice,
        user2.address, //whitelisted buyer
        feeRecipients,
        feePercentages
      );
    });
    it("should allow whitelist buyer to purchase NFT", async function () {
      let user1BalanceBeforePayout = await user1.getBalance();
      let testPlatformBalanceBeforePayout = await testPlatform.getBalance();
      let testArtistBalanceBeforePayout = await testArtist.getBalance();
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, 0, {
          value: minPrice,
        });
      let platformAmount = BigNumber.from(testPlatformBalanceBeforePayout).add(
        BigNumber.from((minPrice * 100) / 10000)
      );
      let artistAmount = BigNumber.from(testArtistBalanceBeforePayout).add(
        BigNumber.from((minPrice * 1000) / 10000)
      );

      let user1Amount = BigNumber.from(minPrice)
        .sub(BigNumber.from((minPrice * 100) / 10000))
        .sub(BigNumber.from((minPrice * 1000) / 10000));
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
});
