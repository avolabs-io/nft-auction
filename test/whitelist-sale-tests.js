const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

const { BigNumber } = require("ethers");
// Enable and inject BN dependency

const tokenId = 1;
const minPrice = 100;
const auctionBidPeriod = 86400; //seconds
const bidIncreasePercentage = 10;

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

    await nftAuction.connect(user1).createWhiteListSale(
      erc721.address,
      tokenId,
      minPrice,
      user2.address //whitelisted buyer
    );
  });
  // whitelisted buyer should be able to purchase NFT
  it("should allow whitelist buyer to purchase NFT", async function () {
    await nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
      value: minPrice,
    });
    expect(await erc721.ownerOf(tokenId)).to.equal(user2.address);
  });
  // non whitelisted buyer should not be able to purchase NFT
  it("should revert non whitelist buyer", async function () {
    await expect(
      nftAuction.connect(user3).makeBid(erc721.address, tokenId, {
        value: minPrice,
      })
    ).to.be.revertedWith("only the whitelisted buyer can bid on this NFT");
    expect(await erc721.ownerOf(tokenId)).to.equal(nftAuction.address);
  });
  //test buyer can't purchase nft below the minimum price
  it("should revert whitelist buyer below sale price", async function () {
    await expect(
      nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
        value: minPrice - 1,
      })
    ).to.be.revertedWith("Bid must be higher than minimum bid");
  });
});
