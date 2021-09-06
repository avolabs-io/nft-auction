const { expect } = require("chai");

const { BigNumber } = require("ethers");

const tokenId = 1;
const minPrice = 100;
const buyNowPrice = 10000;
const newBuyNowPrice = 50000;
const newMinPrice = 50;
const auctionBidPeriod = 86400; //seconds
const bidIncreasePercentage = 1000;
const tokenAmount = 500;
const zeroAddress = "0x0000000000000000000000000000000000000000";
const zeroERC20Tokens = 0;
const emptyFeeRecipients = [];
const emptyFeePercentages = [];
// Deploy and create a mock erc721 contract.
// 1 basic test, NFT sent from one person to another works correctly.
describe("ERC20 New Auction Tests", function () {
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
    await erc721.mint(user1.address, tokenId);

    erc20 = await ERC20.deploy("Mock ERC20", "MER");
    await erc20.deployed();
    await erc20.mint(user2.address, tokenAmount);

    nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();
    //approve our smart contract to transfer this NFT
    await erc721.connect(user1).approve(nftAuction.address, tokenId);
  });
  it("should deploy erc20 token and mint tokens", async function () {
    expect(await erc20.balanceOf(user2.address)).to.equal(
      BigNumber.from(tokenAmount).toString()
    );
  });
  it("should allow user to approve the smart contract", async function () {
    await erc20.connect(user2).approve(nftAuction.address, minPrice);
    expect(await erc20.allowance(user2.address, nftAuction.address)).to.equal(
      BigNumber.from(minPrice).toString()
    );
  });
  it("Calling newNftAuction transfers NFT to contract", async function () {
    await nftAuction
      .connect(user1)
      .createNewNftAuction(
        erc721.address,
        tokenId,
        erc20.address,
        minPrice,
        buyNowPrice,
        auctionBidPeriod,
        bidIncreasePercentage,
        emptyFeeRecipients,
        emptyFeePercentages
      );

    expect(await erc721.ownerOf(tokenId)).to.equal(nftAuction.address);
  });

  it("should not allow minimum bid increase percentage below minimum settable value", async function () {
    await expect(
      nftAuction
        .connect(user1)
        .createNewNftAuction(
          erc721.address,
          tokenId,
          erc20.address,
          minPrice,
          buyNowPrice,
          auctionBidPeriod,
          400,
          emptyFeeRecipients,
          emptyFeePercentages
        )
    ).to.be.revertedWith("Bid increase percentage too low");
  });

  it("should revert new auction with MinPrice of 0", async function () {
    await expect(
      nftAuction
        .connect(user1)
        .createNewNftAuction(
          erc721.address,
          tokenId,
          erc20.address,
          0,
          buyNowPrice,
          auctionBidPeriod,
          bidIncreasePercentage,
          emptyFeeRecipients,
          emptyFeePercentages
        )
    ).to.be.revertedWith("Price cannot be 0");
  });

  it("should allow seller to create default Auction", async function () {
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

    expect(await erc721.ownerOf(tokenId)).to.equal(nftAuction.address);
  });
  it("should not allow minimum bid increase percentage below minimum settable value", async function () {
    await expect(
      nftAuction
        .connect(user1)
        .createNewNftAuction(
          erc721.address,
          tokenId,
          erc20.address,
          minPrice,
          buyNowPrice,
          auctionBidPeriod,
          400,
          emptyFeeRecipients,
          emptyFeePercentages
        )
    ).to.be.revertedWith("Bid increase percentage too low");
  });

  it("should revert new auction with MinPrice & BuyNowPrice of 0", async function () {
    await expect(
      nftAuction
        .connect(user1)
        .createNewNftAuction(
          erc721.address,
          tokenId,
          erc20.address,
          0,
          0,
          auctionBidPeriod,
          bidIncreasePercentage,
          emptyFeeRecipients,
          emptyFeePercentages
        )
    ).to.be.revertedWith("Price cannot be 0");
  });
  it("should not allow seller to set min price greater than buy now price", async function () {
    await expect(
      nftAuction
        .connect(user1)
        .createNewNftAuction(
          erc721.address,
          tokenId,
          erc20.address,
          buyNowPrice,
          minPrice,
          auctionBidPeriod,
          bidIncreasePercentage,
          emptyFeeRecipients,
          emptyFeePercentages
        )
    ).to.be.revertedWith("MinPrice > 80% of buyNowPrice");
  });

  describe("Test when no bids made on new auction", function () {
    beforeEach(async function () {
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
    it("should allow seller to withdraw NFT if no bids made", async function () {
      expect(await erc721.ownerOf(tokenId)).to.equal(nftAuction.address);
      await nftAuction.connect(user1).withdrawNft(erc721.address, tokenId);
      expect(await erc721.ownerOf(tokenId)).to.equal(user1.address);
    });
    it("should reset auction when NFT withdrawn", async function () {
      await nftAuction.connect(user1).withdrawNft(erc721.address, tokenId);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.ERC20Token).to.be.equal(zeroAddress);
    });
    it("should not allow other users to withdraw NFT", async function () {
      await expect(
        nftAuction.connect(user2).withdrawNft(erc721.address, tokenId)
      ).to.be.revertedWith("Only nft seller");
    });
    it("should revert when trying to update whitelisted buyer", async function () {
      await expect(
        nftAuction
          .connect(user1)
          .updateWhitelistedBuyer(erc721.address, tokenId, user3.address)
      ).to.be.revertedWith("Not a sale");
    });
    it("should allow seller to update minimum price", async function () {
      await nftAuction
        .connect(user1)
        .updateMinimumPrice(erc721.address, tokenId, newMinPrice);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.minPrice.toString()).to.be.equal(
        BigNumber.from(newMinPrice).toString()
      );
    });
    it("should not allow seller to update minimum price above buyNowPrice", async function () {
      await expect(
        nftAuction
          .connect(user1)
          .updateMinimumPrice(erc721.address, tokenId, buyNowPrice + 1)
      ).to.be.revertedWith("MinPrice > 80% of buyNowPrice");
    });
    it("should not allow seller to take highest bid when no bid made", async function () {
      await expect(
        nftAuction.connect(user1).takeHighestBid(erc721.address, tokenId)
      ).to.be.revertedWith("cannot payout 0 bid");
    });
    it("should allow seller to update buy now price", async function () {
      await nftAuction
        .connect(user1)
        .updateBuyNowPrice(erc721.address, tokenId, newBuyNowPrice);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.buyNowPrice.toString()).to.be.equal(
        BigNumber.from(newBuyNowPrice).toString()
      );
    });
    it("should not allow other user to update min price", async function () {
      await expect(
        nftAuction
          .connect(user2)
          .updateMinimumPrice(erc721.address, tokenId, newMinPrice)
      ).to.be.revertedWith("Only nft seller");
    });
  });
});
