const { expect } = require("chai");

const { BigNumber } = require("ethers");
const { network } = require("hardhat");

const tokenId = 1;
const minPrice = 10000;
const newPrice = 15000;
const buyNowPrice = 100000;
const tokenBidAmount = 25000;
const tokenAmount = 50000;
const zeroAddress = "0x0000000000000000000000000000000000000000";
const zeroERC20Tokens = 0;
const emptyFeeRecipients = [];
const emptyFeePercentages = [];

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
    bidIncreasePercentage = 1000;
    auctionBidPeriod = 86400;
    beforeEach(async function () {
      await nftAuction
        .connect(user1)
        .createDefaultNftAuction(
          erc721.address,
          tokenId,
          zeroAddress,
          minPrice,
          buyNowPrice,
          emptyFeeRecipients,
          emptyFeePercentages
        );
    });
    it("should allow multiple bids and conclude auction after end period", async function () {
      nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: minPrice,
        });
      const bidIncreaseByMinPercentage =
        (minPrice * (10000 + bidIncreasePercentage)) / 10000;
      await network.provider.send("evm_increaseTime", [auctionBidPeriod / 2]);
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: bidIncreaseByMinPercentage,
        });
      await network.provider.send("evm_increaseTime", [86000]);
      const bidIncreaseByMinPercentage2 =
        (bidIncreaseByMinPercentage * (10000 + bidIncreasePercentage)) / 10000;
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: bidIncreaseByMinPercentage2,
        });
      await network.provider.send("evm_increaseTime", [86001]);
      const bidIncreaseByMinPercentage3 =
        (bidIncreaseByMinPercentage2 * (10000 + bidIncreasePercentage)) / 10000;
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
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
    bidIncreasePercentage = 2000;
    auctionBidPeriod = 106400;
    beforeEach(async function () {
      await nftAuction
        .connect(user1)
        .createNewNftAuction(
          erc721.address,
          tokenId,
          zeroAddress,
          minPrice,
          buyNowPrice,
          auctionBidPeriod,
          bidIncreasePercentage,
          emptyFeeRecipients,
          emptyFeePercentages
        );
    });
    it("should allow multiple bids and conclude auction after end period", async function () {
      nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: minPrice,
        });
      const bidIncreaseByMinPercentage =
        (minPrice * (10000 + bidIncreasePercentage)) / 10000;
      await network.provider.send("evm_increaseTime", [43200]);
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: bidIncreaseByMinPercentage,
        });
      await expect(
        nftAuction
          .connect(user1)
          .updateMinimumPrice(erc721.address, tokenId, newPrice)
      ).to.be.revertedWith("The auction has a valid bid made");

      await network.provider.send("evm_increaseTime", [86000]);
      const bidIncreaseByMinPercentage2 =
        (bidIncreaseByMinPercentage * (10000 + bidIncreasePercentage)) / 10000;
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: bidIncreaseByMinPercentage2,
        });
      await network.provider.send("evm_increaseTime", [86001]);
      const bidIncreaseByMinPercentage3 =
        (bidIncreaseByMinPercentage2 * (10000 + bidIncreasePercentage)) / 10000;
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: bidIncreaseByMinPercentage3,
        });
      //should not be able to settle auction yet
      await expect(
        nftAuction.connect(user3).settleAuction(erc721.address, tokenId)
      ).to.be.revertedWith("Auction is not yet over");
      await network.provider.send("evm_increaseTime", [auctionBidPeriod + 1]);
      //auction has ended

      const bidIncreaseByMinPercentage4 =
        (bidIncreaseByMinPercentage3 * (10000 + bidIncreasePercentage)) / 10000;
      await expect(
        nftAuction
          .connect(user2)
          .makeCustomBid(
            erc721.address,
            tokenId,
            zeroAddress,
            zeroERC20Tokens,
            user4.address,
            {
              value: bidIncreaseByMinPercentage4,
            }
          )
      ).to.be.revertedWith("Auction has ended");
      await nftAuction.connect(user3).settleAuction(erc721.address, tokenId);
      expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);
    });
  });
  describe("Early bid auction end to end", async function () {
    bidIncreasePercentage = 2000;
    auctionBidPeriod = 106400;
    beforeEach(async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: minPrice - 1,
        });
    });
    it("should allow owner to create auction which concludes after multiple bids", async function () {
      await nftAuction
        .connect(user1)
        .createNewNftAuction(
          erc721.address,
          tokenId,
          zeroAddress,
          minPrice,
          buyNowPrice,
          auctionBidPeriod,
          bidIncreasePercentage,
          emptyFeeRecipients,
          emptyFeePercentages
        );

      await expect(
        nftAuction
          .connect(user2)
          .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
            value: minPrice,
          })
      ).to.be.revertedWith("Not enough funds to bid on NFT");

      const bidIncreaseByMinPercentage =
        (minPrice * (10000 + bidIncreasePercentage)) / 10000;
      await network.provider.send("evm_increaseTime", [43200]);
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: bidIncreaseByMinPercentage,
        });
      await network.provider.send("evm_increaseTime", [86000]);
      const bidIncreaseByMinPercentage2 =
        (bidIncreaseByMinPercentage * (10000 + bidIncreasePercentage)) / 10000;
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: bidIncreaseByMinPercentage2,
        });
      await network.provider.send("evm_increaseTime", [86001]);
      const bidIncreaseByMinPercentage3 =
        (bidIncreaseByMinPercentage2 * (10000 + bidIncreasePercentage)) / 10000;
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
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
    bidIncreasePercentage = 2000;
    auctionBidPeriod = 106400;
    beforeEach(async function () {
      await nftAuction
        .connect(user1)
        .createNewNftAuction(
          erc721.address,
          tokenId,
          zeroAddress,
          minPrice,
          buyNowPrice,
          auctionBidPeriod,
          bidIncreasePercentage,
          emptyFeeRecipients,
          emptyFeePercentages
        );
    });
    it("should allow multiple custom bids and conclude auction after end period", async function () {
      nftAuction
        .connect(user2)
        .makeCustomBid(
          erc721.address,
          tokenId,
          zeroAddress,
          zeroERC20Tokens,
          user4.address,
          {
            value: minPrice,
          }
        );
      const bidIncreaseByMinPercentage =
        (minPrice * (10000 + bidIncreasePercentage)) / 10000;
      await network.provider.send("evm_increaseTime", [43200]);
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: bidIncreaseByMinPercentage,
        });
      await network.provider.send("evm_increaseTime", [86000]);
      const bidIncreaseByMinPercentage2 =
        (bidIncreaseByMinPercentage * (10000 + bidIncreasePercentage)) / 10000;
      await nftAuction
        .connect(user2)
        .makeCustomBid(
          erc721.address,
          tokenId,
          zeroAddress,
          zeroERC20Tokens,
          user4.address,
          {
            value: bidIncreaseByMinPercentage2,
          }
        );
      await network.provider.send("evm_increaseTime", [86001]);
      const bidIncreaseByMinPercentage3 =
        (bidIncreaseByMinPercentage2 * (10000 + bidIncreasePercentage)) / 10000;
      await nftAuction
        .connect(user3)
        .makeCustomBid(
          erc721.address,
          tokenId,
          zeroAddress,
          zeroERC20Tokens,
          user4.address,
          {
            value: bidIncreaseByMinPercentage3,
          }
        );
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
  describe("ERC20 auction end to end", async function () {
    bidIncreasePercentage = 1000;
    auctionBidPeriod = 86400;
    beforeEach(async function () {
      ERC20 = await ethers.getContractFactory("ERC20MockContract");

      erc20 = await ERC20.deploy("Mock ERC20", "MER");
      await erc20.deployed();
      await erc20.mint(user1.address, tokenAmount);
      await erc20.mint(user2.address, tokenAmount);

      await erc20.mint(user3.address, tokenAmount);

      otherErc20 = await ERC20.deploy("OtherToken", "OTK");
      await otherErc20.deployed();

      await otherErc20.mint(user3.address, tokenAmount);

      await erc20.connect(user1).approve(nftAuction.address, tokenAmount);
      await erc20.connect(user2).approve(nftAuction.address, tokenBidAmount);
      await erc20.connect(user3).approve(nftAuction.address, tokenAmount);
      await otherErc20.connect(user3).approve(nftAuction.address, tokenAmount);

      await nftAuction
        .connect(user1)
        .createDefaultNftAuction(
          erc721.address,
          tokenId,
          erc20.address,
          minPrice,
          buyNowPrice,
          emptyFeeRecipients,
          emptyFeePercentages
        );
    });
    it("should allow multiple bids and conclude auction after end period", async function () {
      nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, erc20.address, minPrice);
      const bidIncreaseByMinPercentage =
        (minPrice * (10000 + bidIncreasePercentage)) / 10000;
      await network.provider.send("evm_increaseTime", [auctionBidPeriod / 2]);
      await nftAuction
        .connect(user3)
        .makeBid(
          erc721.address,
          tokenId,
          erc20.address,
          bidIncreaseByMinPercentage
        );
      await network.provider.send("evm_increaseTime", [86000]);
      const bidIncreaseByMinPercentage2 =
        (bidIncreaseByMinPercentage * (10000 + bidIncreasePercentage)) / 10000;
      await nftAuction
        .connect(user2)
        .makeBid(
          erc721.address,
          tokenId,
          erc20.address,
          bidIncreaseByMinPercentage2
        );
      await network.provider.send("evm_increaseTime", [86001]);
      const bidIncreaseByMinPercentage3 =
        (bidIncreaseByMinPercentage2 * (10000 + bidIncreasePercentage)) / 10000;
      await expect(
        nftAuction
          .connect(user3)
          .makeCustomBid(
            erc721.address,
            tokenId,
            otherErc20.address,
            bidIncreaseByMinPercentage3,
            user3.address
          )
      ).to.be.revertedWith(
        "Bid to be made in quantities of specified token or eth"
      );
      await expect(
        nftAuction
          .connect(user3)
          .makeCustomBid(
            erc721.address,
            tokenId,
            zeroAddress,
            zeroERC20Tokens,
            user4.address,
            {
              value: bidIncreaseByMinPercentage3,
            }
          )
      ).to.be.revertedWith(
        "Bid to be made in quantities of specified token or eth"
      );
      await nftAuction
        .connect(user3)
        .makeBid(
          erc721.address,
          tokenId,
          erc20.address,
          bidIncreaseByMinPercentage3
        );
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
});
