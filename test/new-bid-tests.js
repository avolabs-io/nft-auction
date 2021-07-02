const { expect } = require("chai");

const { BigNumber } = require("ethers");
// Enable and inject BN dependency

const tokenId = 1;
const minPrice = 10;
const auctionLength = 100; //seconds

// Deploy and create a mock erc721 contract.

describe("NFTAuction Bids", function () {
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
      .connect(user1)
      .createNewNftAuction(erc721.address, tokenId, minPrice, auctionLength);
  });
  // 1 basic test, NFT put up for auction can accept bids with ETH
  it("Calling makeBid to bid on new NFTAuction", async function () {
    await nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
      value: minPrice,
    });
    let result = await nftAuction.nftContractAuctions(erc721.address, tokenId);
    expect(result.nftHighestBidder).to.equal(user2.address);
    expect(result.nftHighestBid.toString()).to.be.equal(
      BigNumber.from(minPrice).toString()
    );
  });
});
