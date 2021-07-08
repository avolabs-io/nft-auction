const { expect } = require("chai");

const { BigNumber } = require("ethers");
const { network } = require("hardhat");

const tokenIdMaster = 1;
const layers = [2, 3, 4, 5, 6, 7, 8, 9, 10];
const minPrice = 10000;
const newPrice = 15000;
const auctionBidPeriod = 86400; //seconds

// Deploy and create a mock erc721 contract.
// Test end to end auction
describe("Batch Auction", function () {
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
  //deploy mock erc721 token
  beforeEach(async function () {
    ERC721 = await ethers.getContractFactory("ERC721MockContract");
    NFTAuction = await ethers.getContractFactory("NFTAuction");
    [ContractOwner, user1, user2, user3, user4] = await ethers.getSigners();

    erc721 = await ERC721.deploy("my mockables", "MBA");
    await erc721.deployed();
    await erc721.mint(user1.address, tokenIdMaster);
    for (let i = 0; i < layers.length; i++) {
      await erc721.mint(user1.address, layers[i]);
    }

    nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();
    //approve our smart contract to transfer this NFT
    await erc721.connect(user1).approve(nftAuction.address, tokenIdMaster);
    for (let i = 0; i < layers.length; i++) {
      await erc721.connect(user1).approve(nftAuction.address, layers[i]);
    }
  });
  it("should allow batch auctions", async function () {
    await nftAuction
      .connect(user1)
      .createBatchNftAuction(erc721.address, tokenIdMaster, minPrice, layers);
    expect(await erc721.ownerOf(tokenIdMaster)).to.equal(nftAuction.address);
    for (let i = 0; i < layers.length; i++) {
      expect(await erc721.ownerOf(layers[i])).to.equal(nftAuction.address);
    }
  });
  it("should revert if minimum price equal 0", async function () {
    await expect(
      nftAuction
        .connect(user1)
        .createBatchNftAuction(erc721.address, tokenIdMaster, 0, layers)
    ).to.be.revertedWith("Minimum price cannot be 0");
  });
  describe("Batch Auction Bids and settlement tests", async function () {
    beforeEach(async function () {
      await nftAuction
        .connect(user1)
        .createBatchNftAuction(erc721.address, tokenIdMaster, minPrice, layers);
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
    });
    it("should allow bids on batch auction", async function () {
      await nftAuction.connect(user2).makeBid(erc721.address, tokenIdMaster, {
        value: minPrice,
      });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenIdMaster
      );
      expect(result.nftHighestBidder).to.equal(user2.address);
      expect(result.nftHighestBid.toString()).to.be.equal(
        BigNumber.from(minPrice).toString()
      );
    });
    it("should transfer nfts to buyer when auction is over", async function () {
      await nftAuction.connect(user2).makeBid(erc721.address, tokenIdMaster, {
        value: minPrice,
      });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenIdMaster
      );
      expect(result.auctionEnd.toString()).to.be.not.equal(
        BigNumber.from(0).toString()
      );
      await network.provider.send("evm_increaseTime", [auctionBidPeriod + 1]);
      //auction has ended
      await nftAuction
        .connect(user2)
        .settleAuction(erc721.address, tokenIdMaster);
      expect(await erc721.ownerOf(tokenIdMaster)).to.equal(user2.address);
      for (let i = 0; i < layers.length; i++) {
        expect(await erc721.ownerOf(layers[i])).to.equal(user2.address);
      }
    });
  });
  describe("Test early bids with batch auctions", async function () {
    this.beforeEach(async function () {
      await nftAuction.connect(user2).makeBid(erc721.address, tokenIdMaster, {
        value: minPrice,
      });
    });
    it(" should create auction and transfer NFTs to contract", async function () {
      await nftAuction
        .connect(user1)
        .createBatchNftAuction(erc721.address, tokenIdMaster, minPrice, layers);
      expect(await erc721.ownerOf(tokenIdMaster)).to.equal(nftAuction.address);
      for (let i = 0; i < layers.length; i++) {
        expect(await erc721.ownerOf(layers[i])).to.equal(nftAuction.address);
      }
    });
    it("should start the auction as min price is met", async function () {
      await nftAuction
        .connect(user1)
        .createBatchNftAuction(erc721.address, tokenIdMaster, minPrice, layers);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenIdMaster
      );
      expect(result.auctionEnd).to.be.not.equal(BigNumber.from(0).toString());
    });
  });
});
