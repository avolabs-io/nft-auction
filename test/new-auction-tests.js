const { expect } = require("chai");

const tokenId = 1;
const minPrice = 10;
const auctionBidPeriod = 86400; //seconds
const bidIncreasePercentage = 10;

// Deploy and create a mock erc721 contract.
// 1 basic test, NFT sent from one person to another works correctly.
describe("NFTAuction", function () {
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
  });

  it("Deploy mock erc721 and mint erc721 token", async function () {
    expect(await erc721.ownerOf(1)).to.equal(user1.address);
  });

  it("Calling newNftAuction transfers NFT to contract", async function () {
    await nftAuction
      .connect(user1)
      .createNewNftAuction(
        erc721.address,
        tokenId,
        minPrice,
        auctionBidPeriod,
        bidIncreasePercentage
      );

    expect(await erc721.ownerOf(1)).to.equal(nftAuction.address);
  });

  it("should revert new auction with MinPrice of 0", async function () {
    await expect(
      nftAuction
        .connect(user1)
        .createNewNftAuction(
          erc721.address,
          tokenId,
          0,
          auctionBidPeriod,
          bidIncreasePercentage
        )
    ).to.be.revertedWith("Minimum price cannot be 0");
  });
});
