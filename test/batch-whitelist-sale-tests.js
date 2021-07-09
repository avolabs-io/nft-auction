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
describe("Batch Whitelist Sale", function () {
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
    await erc721.connect(user1).setApprovalForAll(nftAuction.address, true);
  });
  it("should allow batch whitelist sales", async function () {
    await nftAuction
      .connect(user1)
      .createBatchWhiteListSale(
        erc721.address,
        tokenIdMaster,
        minPrice,
        layers,
        user2.address
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
          0,
          layers,
          user2.address
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
          minPrice,
          layers,
          user2.address
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
    it("should allow sale to complete on for whitelisted buyer", async function () {
      await nftAuction.connect(user2).makeBid(erc721.address, tokenIdMaster, {
        value: minPrice,
      });
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
      await nftAuction.connect(user2).makeBid(erc721.address, tokenIdMaster, {
        value: minPrice,
      });
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
    });
    it("should allow whitelist buyer to purchase NFT and add recipient", async function () {
      await nftAuction
        .connect(user2)
        .makeCustomBid(erc721.address, tokenIdMaster, user3.address, {
          value: minPrice,
        });
      expect(await erc721.ownerOf(tokenIdMaster)).to.equal(user3.address);
      for (let i = 0; i < layers.length; i++) {
        expect(await erc721.ownerOf(layers[i])).to.equal(user3.address);
      }
    });
    it("should revert non whitelist buyer", async function () {
      await expect(
        nftAuction.connect(user3).makeBid(erc721.address, tokenIdMaster, {
          value: minPrice,
        })
      ).to.be.revertedWith("only the whitelisted buyer can bid on this NFT");
      expect(await erc721.ownerOf(tokenIdMaster)).to.equal(nftAuction.address);
    });
    it("should revert whitelist buyer below sale price", async function () {
      await expect(
        nftAuction.connect(user2).makeBid(erc721.address, tokenIdMaster, {
          value: minPrice - 1,
        })
      ).to.be.revertedWith("Bid must be higher than minimum bid");
    });
    it("should allow seller to update whitelisted buyer", async function () {
      await nftAuction
        .connect(user1)
        .updateWhitelistedBuyer(erc721.address, tokenIdMaster, user3.address);
      await expect(
        nftAuction.connect(user2).makeBid(erc721.address, tokenIdMaster, {
          value: minPrice,
        })
      ).to.be.revertedWith("only the whitelisted buyer can bid on this NFT");
      await nftAuction.connect(user3).makeBid(erc721.address, tokenIdMaster, {
        value: minPrice,
      });
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
  /*
   ****Test Early Bid function on batch whitelisted sales****
   */
  describe("Test early bids with batch auctions", async function () {
    let underBid = minPrice - 1000;
    let result;
    this.beforeEach(async function () {
      await nftAuction.connect(user2).makeBid(erc721.address, tokenIdMaster, {
        value: underBid,
      });
    });
    it("shouuld transfer nft to whitelisted early bidder", async function () {
      await nftAuction.connect(user3).makeBid(erc721.address, tokenIdMaster, {
        value: minPrice,
      });
      await nftAuction
        .connect(user1)
        .createBatchWhiteListSale(
          erc721.address,
          tokenIdMaster,
          minPrice,
          layers,
          user3.address
        );

      expect(await erc721.ownerOf(tokenIdMaster)).to.equal(user3.address);
      for (let i = 0; i < layers.length; i++) {
        expect(await erc721.ownerOf(layers[i])).to.equal(user3.address);
      }
    });
    it("should rever early bid from non whitelisted buyer", async function () {
      await nftAuction.connect(user3).makeBid(erc721.address, tokenIdMaster, {
        value: minPrice,
      });
      await nftAuction
        .connect(user1)
        .createBatchWhiteListSale(
          erc721.address,
          tokenIdMaster,
          minPrice,
          layers,
          user2.address
        );
      result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenIdMaster
      );
      expect(result.nftHighestBidder).to.be.equal(
        "0x0000000000000000000000000000000000000000"
      );
      //   expect(await erc721.ownerOf(tokenIdMaster)).to.equal(user3.address);
      //   for (let i = 0; i < layers.length; i++) {
      //     expect(await erc721.ownerOf(layers[i])).to.equal(user3.address);
      //   }
    });
    it("should revert underbid if whitelist sale created", async function () {
      await nftAuction
        .connect(user1)
        .createBatchWhiteListSale(
          erc721.address,
          tokenIdMaster,
          minPrice,
          layers,
          user2.address
        );
      result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenIdMaster
      );
      expect(result.nftHighestBidder).to.be.equal(
        "0x0000000000000000000000000000000000000000"
      );
    });
  });
});
