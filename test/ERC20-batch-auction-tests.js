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

// Deploy and create a mock erc721 contract.
// Test end to end auction
describe("Batch Auctions with ERC20 Tokens", function () {
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

    nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();
    //approve our smart contract to transfer this NFT
    await erc721.connect(user1).approve(nftAuction.address, tokenIdMaster);
    await erc721.connect(user1).setApprovalForAll(nftAuction.address, true);

    await erc20.connect(user1).approve(nftAuction.address, tokenAmount);
    await erc20.connect(user2).approve(nftAuction.address, tokenBidAmount);
    await erc20.connect(user3).approve(nftAuction.address, tokenAmount);
  });
  it("should allow batch auctions", async function () {
    await nftAuction
      .connect(user1)
      .createDefaultBatchNftAuction(
        erc721.address,
        tokenIdMaster,
        erc20.address,
        minPrice,
        layers
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
        .createDefaultBatchNftAuction(
          erc721.address,
          tokenIdMaster,
          erc20.address,
          0,
          layers
        )
    ).to.be.revertedWith("Minimum price cannot be 0");
  });

  describe(" Default Batch Auction Bids and settlement tests", async function () {
    beforeEach(async function () {
      await nftAuction
        .connect(user1)
        .createDefaultBatchNftAuction(
          erc721.address,
          tokenIdMaster,
          erc20.address,
          minPrice,
          layers
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
    });
    it("should allow bids on batch auction", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenIdMaster, erc20.address, minPrice);
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
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenIdMaster, erc20.address, minPrice);
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
  /*
   ****Test custom batch auctions****
   */
  describe(" Custom Batch Auction Bids and settlement tests", async function () {
    beforeEach(async function () {
      bidIncreasePercentage = 15;
      await nftAuction
        .connect(user1)
        .createBatchNftAuction(
          erc721.address,
          tokenIdMaster,
          erc20.address,
          minPrice,
          layers,
          auctionBidPeriod,
          bidIncreasePercentage
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
      expect(result.ERC20Token).to.be.equal(zeroAddress);
    });
    it("should allow bids on batch auction", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenIdMaster, erc20.address, minPrice);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenIdMaster
      );
      expect(result.nftHighestBidder).to.equal(user2.address);
      expect(result.nftHighestBid.toString()).to.be.equal(
        BigNumber.from(minPrice).toString()
      );
    });
    it("should transfer nfts to buyer & pay seller when auction is over", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenIdMaster, erc20.address, minPrice);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenIdMaster
      );
      expect(result.auctionEnd.toString()).to.be.not.equal(
        BigNumber.from(0).toString()
      );
      expect(await erc20.balanceOf(user1.address)).to.equal(
        BigNumber.from(tokenAmount).toString()
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
      expect(await erc20.balanceOf(user1.address)).to.equal(
        BigNumber.from(tokenAmount + minPrice).toString()
      );
    });
  });
});
