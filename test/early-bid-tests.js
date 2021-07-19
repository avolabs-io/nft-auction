const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

const { BigNumber } = require("ethers");
// Enable and inject BN dependency

const tokenId = 1;
const minPrice = 100;
const newMinPrice = 50;
const auctionBidPeriod = 86400; //seconds
const bidIncreasePercentage = 10;
const zeroAddress = "0x0000000000000000000000000000000000000000";
const zeroERC20Tokens = 0;
const emptyFeeRecipients = [];
const emptyFeePercentages = [];

// Deploy and create a mock erc721 contract.

describe("Early bid tests", function () {
  let ERC721;
  let erc721;
  let NFTAuction;
  let nftAuction;
  let contractOwner;
  let user1;
  let user2;
  let user3;

  beforeEach(async function () {
    ERC721 = await ethers.getContractFactory("ERC721MockContract");
    NFTAuction = await ethers.getContractFactory("NFTAuction");
    [ContractOwner, user1, user2, user3] = await ethers.getSigners();

    erc721 = await ERC721.deploy("my mockables", "MBA");
    await erc721.deployed();
    await erc721.mint(user1.address, 1);

    nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();
    //approve our smart contract to transfer this NFT
    await erc721.connect(user1).approve(nftAuction.address, 1);

    await nftAuction
      .connect(user2)
      .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
        value: minPrice,
      });
  });
  // whitelisted buyer should be able to purchase NFT
  it("should allow early bids on NFTs", async function () {
    let result = await nftAuction.nftContractAuctions(erc721.address, tokenId);
    expect(result.nftHighestBidder).to.equal(user2.address);
    expect(result.nftHighestBid.toString()).to.be.equal(
      BigNumber.from(minPrice).toString()
    );
  });
  it("should allow NFT owner to create auction", async function () {
    await nftAuction
      .connect(user1)
      .createDefaultNftAuction(
        erc721.address,
        tokenId,
        zeroAddress,
        minPrice,
        emptyFeeRecipients,
        emptyFeePercentages
      );

    let result = await nftAuction.nftContractAuctions(erc721.address, tokenId);
    expect(result.minPrice).to.equal(BigNumber.from(minPrice).toString());
  });
  it("should start auction period if early bid is higher than minimum", async function () {
    await nftAuction
      .connect(user1)
      .createDefaultNftAuction(
        erc721.address,
        tokenId,
        zeroAddress,
        minPrice,
        emptyFeeRecipients,
        emptyFeePercentages
      );

    let result = await nftAuction.nftContractAuctions(erc721.address, tokenId);
    expect(result.auctionEnd).to.be.not.equal(BigNumber.from(0).toString());
  });
  it("should start auction period if early bid greater than minimum", async function () {
    await nftAuction
      .connect(user1)
      .createDefaultNftAuction(
        erc721.address,
        tokenId,
        zeroAddress,
        minPrice - 1,
        emptyFeeRecipients,
        emptyFeePercentages
      );

    let result = await nftAuction.nftContractAuctions(erc721.address, tokenId);
    expect(result.auctionEnd).to.be.not.equal(BigNumber.from(0).toString());
  });
  it("should not allow minPrice to be updated by other users", async function () {
    await expect(
      nftAuction
        .connect(user2)
        .updateMinimumPrice(erc721.address, tokenId, newMinPrice)
    ).to.be.revertedWith("Only the owner can call this function");
  });
});
