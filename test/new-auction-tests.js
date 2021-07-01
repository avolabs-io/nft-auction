const { expect } = require("chai");

// Deploy and create a mock erc721 contract.
// 1 basic test, NFT sent from one person to another works correctly.
describe("NFTAuction", function () {
  it("Deploy mock erc721 and mint erc721 token", async function () {
    const [contractOwner, user1, user2, user3] = await ethers.getSigners();

    const ERC721 = await ethers.getContractFactory("ERC721MockContract");
    const erc721 = await ERC721.deploy("my mockables", "MBA");
    await erc721.deployed();

    await erc721.mint(user1.address, 1);

    expect(await erc721.ownerOf(1)).to.equal(user1.address);
  });

  it("Calling newNftAuction transfers NFT to contract", async function () {
    const [contractOwner, user1, user2, user3] = await ethers.getSigners();

    // deploy erc721 mock
    const ERC721 = await ethers.getContractFactory("ERC721MockContract");
    const erc721 = await ERC721.deploy("my mockables", "MBA");
    await erc721.deployed();

    // deploy nft auction contract
    const NFTAuction = await ethers.getContractFactory("NFTAuction");
    const nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();

    // mint nft for user1
    await erc721.mint(user1.address, 1);
    await erc721.connect(user1).approve(nftAuction.address, 1);
    await nftAuction
      .connect(user1)
      .createNewNftAuction(erc721.address, 1, 10, 100);

    expect(await erc721.ownerOf(1)).to.equal(nftAuction.address);
  });
});
