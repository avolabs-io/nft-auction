const { expect, assert } = require("chai");

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

  describe("Function: makeBid", () => {
    it("1st require: Ensure owner cannot bid on own NFT", async () => {
      await nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
        value: minPrice,
      });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      assert(result.nftSeller != user2.address);
    });

    it("2nd require: Ensure initial bid is higher than minimum bid", async () => {
      // I'm assuming this require is for the initial bid only, because the 3rd require
      // would ensure all subsequent bids to be bigger than minPrice set by NFT owner
      await nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
        value: minPrice + 1,
      });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      assert(
        result.nftHighestBid.toString() > BigNumber.from(minPrice).toString(),
        "initial bid not higher than minimum bid"
      );
    });

    it("3rd require: Ensure bid increment >= 10%", async () => {
      await nftAuction.connect(user2).makeBid(erc721.address, tokenId, {
        value: (minPrice * 11) / 10,
      });
      let bid = await nftAuction.nftContractAuctions(erc721.address, tokenId);
      assert(
        bid.nftHighestBid.toString() >= (BigNumber.from(minPrice) * 11) / 10,
        "10% or higher bid increment over current highest bid, not met"
      );
    });
    // test for full functionality of makeBid still needed
  });

  describe("Function: _updateAuctionEnd", () => {
    it.skip("[unfinished] if min bid made, updates auctionEnd by another auctionLength", async () => {
      assert(true);
    });

    it.skip("[unfinished] if min bid not made, updates __  ", async () => {
      assert(true);
    });
  });
});
