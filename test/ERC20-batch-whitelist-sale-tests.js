const { expect } = require("chai");

const { BigNumber } = require("ethers");
const { network } = require("hardhat");

const tokenIdMaster = 1;

const minPrice = 10000;
const newPrice = 15000;
const tokenBidAmount = 25000;
const tokenAmount = 50000;
const auctionBidPeriod = 106400; //seconds
const layers = [2, 3, 4, 5, 6, 7, 8, 9, 10];
const zeroAddress = "0x0000000000000000000000000000000000000000";
const zeroERC20Tokens = 0;
const emptyFeeRecipients = [];
const emptyFeePercentages = [];

// Deploy and create a mock erc721 contract.
// Test end to end auction
describe("Batch Whitelist Sales with ERC20 Tokens", function () {
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
  let user4;
  let bidIncreasePercentage;
  let MaxLayers;

  //deploy mock erc721 token
  beforeEach(async function () {
    ERC721 = await ethers.getContractFactory("ERC721MockContract");
    ERC20 = await ethers.getContractFactory("ERC20MockContract");
    NFTAuction = await ethers.getContractFactory("NFTAuction");
    [ContractOwner, user1, user2, user3, user4] = await ethers.getSigners();

    erc721 = await ERC721.deploy("my mockables", "MBA");
    await erc721.deployed();
    await erc721.mint(user1.address, tokenIdMaster);
    for (let i = 0; i < layers.length; i++) {
      await erc721.mint(user1.address, layers[i]);
    }

    erc20 = await ERC20.deploy("Mock ERC20", "MER");
    await erc20.deployed();

    await erc20.mint(user1.address, tokenAmount);
    await erc20.mint(user2.address, tokenAmount);
    await erc20.mint(user3.address, tokenAmount);

    nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();
    //approve our smart contract to transfer this NFT
    await erc721.connect(user1).approve(nftAuction.address, tokenIdMaster);
    await erc721.connect(user1).setApprovalForAll(nftAuction.address, true);

    await erc20.connect(user1).approve(nftAuction.address, tokenAmount);
    await erc20.connect(user2).approve(nftAuction.address, tokenBidAmount);
    await erc20.connect(user3).approve(nftAuction.address, tokenAmount);
  });
  it("should allow batch whitelist sales", async function () {
    await nftAuction
      .connect(user1)
      .createBatchWhiteListSale(
        erc721.address,
        tokenIdMaster,
        erc20.address,
        minPrice,
        layers,
        user2.address,
        emptyFeeRecipients,
        emptyFeePercentages
      );
    expect(await erc721.ownerOf(tokenIdMaster)).to.equal(nftAuction.address);
    for (let i = 0; i < layers.length; i++) {
      expect(await erc721.ownerOf(layers[i])).to.equal(nftAuction.address);
    }
  });
  it("should revert if minimum price equal 0", async function () {
    await expect(
      nftAuction
        .connect(user1)
        .createBatchWhiteListSale(
          erc721.address,
          tokenIdMaster,
          erc20.address,
          0,
          layers,
          user2.address,
          emptyFeeRecipients,
          emptyFeePercentages
        )
    ).to.be.revertedWith("Minimum price cannot be 0");
  });
  describe("Batch whitelist sale and settlement tests", async function () {
    beforeEach(async function () {
      await nftAuction
        .connect(user1)
        .createBatchWhiteListSale(
          erc721.address,
          tokenIdMaster,
          erc20.address,
          minPrice,
          layers,
          user2.address,
          emptyFeeRecipients,
          emptyFeePercentages
        );
    });
    it("should allow seller to withdraw NFTs if no bids made", async function () {
      await nftAuction
        .connect(user1)
        .withdrawNft(erc721.address, tokenIdMaster);
      expect(await erc721.ownerOf(tokenIdMaster)).to.equal(user1.address);
      for (let i = 0; i < layers.length; i++) {
        expect(await erc721.ownerOf(layers[i])).to.equal(user1.address);
      }
    });
    it("should reset auction when NFT withdrawn", async function () {
      await nftAuction
        .connect(user1)
        .withdrawNft(erc721.address, tokenIdMaster);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenIdMaster
      );
      expect(result.minPrice.toString()).to.be.equal(
        BigNumber.from(0).toString()
      );
      expect(result.ERC20Token).to.be.equal(zeroAddress);
    });
    it("should allow sale to complete for whitelisted buyer", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenIdMaster, erc20.address, minPrice);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenIdMaster
      );
      expect(await erc721.ownerOf(tokenIdMaster)).to.equal(user2.address);
      for (let i = 0; i < layers.length; i++) {
        expect(await erc721.ownerOf(layers[i])).to.equal(user2.address);
      }
    });
    it("should reset variable if sale successful", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenIdMaster, erc20.address, minPrice);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenIdMaster
      );
      expect(result.minPrice.toString()).to.be.equal(
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
          tokenIdMaster,
          erc20.address,
          minPrice,
          user3.address
        );
      expect(await erc721.ownerOf(tokenIdMaster)).to.equal(user3.address);
      for (let i = 0; i < layers.length; i++) {
        expect(await erc721.ownerOf(layers[i])).to.equal(user3.address);
      }
    });
    it("should revert non whitelist buyer", async function () {
      await expect(
        nftAuction
          .connect(user3)
          .makeBid(erc721.address, tokenIdMaster, erc20.address, minPrice)
      ).to.be.revertedWith("only the whitelisted buyer can bid on this NFT");
      expect(await erc721.ownerOf(tokenIdMaster)).to.equal(nftAuction.address);
    });
    it("should revert whitelist buyer below sale price", async function () {
      await expect(
        nftAuction
          .connect(user2)
          .makeBid(erc721.address, tokenIdMaster, erc20.address, minPrice - 1)
      ).to.be.revertedWith("Bid must be higher than minimum bid");
    });
    it("should allow seller to update whitelisted buyer", async function () {
      await nftAuction
        .connect(user1)
        .updateWhitelistedBuyer(erc721.address, tokenIdMaster, user3.address);
      await expect(
        nftAuction
          .connect(user2)
          .makeBid(erc721.address, tokenIdMaster, erc20.address, minPrice)
      ).to.be.revertedWith("only the whitelisted buyer can bid on this NFT");
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenIdMaster, erc20.address, minPrice);
      expect(await erc721.ownerOf(tokenIdMaster)).to.equal(user3.address);
      for (let i = 0; i < layers.length; i++) {
        expect(await erc721.ownerOf(layers[i])).to.equal(user3.address);
      }
      expect(await erc721.ownerOf(tokenIdMaster)).to.equal(user3.address);
    });
    it("should not allow other users to update whitelisted buyer", async function () {
      await expect(
        nftAuction
          .connect(user2)
          .updateWhitelistedBuyer(erc721.address, tokenIdMaster, user3.address)
      ).to.be.revertedWith("Only the owner can call this function");
    });
  });
});
