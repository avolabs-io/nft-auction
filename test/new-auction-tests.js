const { expect } = require("chai");

const { BigNumber } = require("ethers");

const tokenId = 1;
const minPrice = 100;
const newMinPrice = 50;
const auctionBidPeriod = 86400; //seconds
const bidIncreasePercentage = 1000;
const zeroAddress = "0x0000000000000000000000000000000000000000";
const emptyFeeRecipients = [];
const emptyFeePercentages = [];
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
  let testArtist;
  let testPlatform;
  let feeRecipients;
  let feePercentages;

  beforeEach(async function () {
    ERC721 = await ethers.getContractFactory("ERC721MockContract");
    NFTAuction = await ethers.getContractFactory("NFTAuction");
    [ContractOwner, user1, user2, user3, testArtist, testPlatform] =
      await ethers.getSigners();
    erc721 = await ERC721.deploy("my mockables", "MBA");
    await erc721.deployed();
    await erc721.mint(user1.address, tokenId);
    feeRecipients = [testArtist.address, testPlatform.address];
    feePercentages = [1000, 100];
    nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();
    //approve our smart contract to transfer this NFT
    await erc721.connect(user1).approve(nftAuction.address, tokenId);
  });

  it("Deploy mock erc721 and mint erc721 token", async function () {
    expect(await erc721.ownerOf(tokenId)).to.equal(user1.address);
  });

  it("Calling newNftAuction transfers NFT to contract", async function () {
    await nftAuction
      .connect(user1)
      .createNewNftAuction(
        erc721.address,
        tokenId,
        zeroAddress,
        minPrice,
        auctionBidPeriod,
        bidIncreasePercentage,
        emptyFeeRecipients,
        emptyFeePercentages
      );

    expect(await erc721.ownerOf(tokenId)).to.equal(nftAuction.address);
  });
  it("transferring nft token directly to contract", async function () {
    await erc721
      .connect(user1)
      .transferFrom(user1.address, nftAuction.address, tokenId);
    expect(await erc721.ownerOf(tokenId)).to.equal(nftAuction.address);
  });

  it("should not allow minimum bid increase percentage below minimum settable value", async function () {
    await expect(
      nftAuction
        .connect(user1)
        .createNewNftAuction(
          erc721.address,
          tokenId,
          zeroAddress,
          minPrice,
          auctionBidPeriod,
          4,
          emptyFeeRecipients,
          emptyFeePercentages
        )
    ).to.be.revertedWith(
      "Bid increase percentage must be greater than minimum settable increase percentage"
    );
  });

  it("should revert new auction with MinPrice of 0", async function () {
    await expect(
      nftAuction
        .connect(user1)
        .createNewNftAuction(
          erc721.address,
          tokenId,
          zeroAddress,
          0,
          auctionBidPeriod,
          bidIncreasePercentage,
          emptyFeeRecipients,
          emptyFeePercentages
        )
    ).to.be.revertedWith("Minimum price cannot be 0");
  });

  it("should allow seller to create default Auction", async function () {
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

    expect(await erc721.ownerOf(tokenId)).to.equal(nftAuction.address);
  });
  it("shoulld allow seller to specify fees", async function () {
    await nftAuction
      .connect(user1)
      .createDefaultNftAuction(
        erc721.address,
        tokenId,
        zeroAddress,
        minPrice,
        feeRecipients,
        feePercentages
      );
    expect(await erc721.ownerOf(tokenId)).to.equal(nftAuction.address);
  });
  it("shoulld revert if fees exceed 100%", async function () {
    feePercentages = [9900, 1200]; // max = 10000
    await expect(
      nftAuction
        .connect(user1)
        .createDefaultNftAuction(
          erc721.address,
          tokenId,
          zeroAddress,
          minPrice,
          feeRecipients,
          feePercentages
        )
    ).to.be.revertedWith("fee percentages exceed maximum");
  });
  it("shoulld revert if recipients and percentages do not align", async function () {
    feePercentages = [1000];
    await expect(
      nftAuction
        .connect(user1)
        .createDefaultNftAuction(
          erc721.address,
          tokenId,
          zeroAddress,
          minPrice,
          feeRecipients,
          feePercentages
        )
    ).to.be.revertedWith("mismatched fee recipients and percentages");
  });

  describe("Test when no bids made on new auction", function () {
    beforeEach(async function () {
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
      expect(result.minPrice.toString()).to.be.equal(
        BigNumber.from(0).toString()
      );
      expect(result.nftSeller).to.be.equal(zeroAddress);
    });
    it("should not allow other users to withdraw NFT", async function () {
      await expect(
        nftAuction.connect(user2).withdrawNft(erc721.address, tokenId)
      ).to.be.revertedWith("Only the owner can call this function");
    });
    it("should revert when trying to update whitelisted buyer", async function () {
      await expect(
        nftAuction
          .connect(user1)
          .updateWhitelistedBuyer(erc721.address, tokenId, user3.address)
      ).to.be.revertedWith("Not a whitelisted sale");
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
    it("should not allow other user to update min price", async function () {
      await expect(
        nftAuction
          .connect(user2)
          .updateMinimumPrice(erc721.address, tokenId, newMinPrice)
      ).to.be.revertedWith("Only the owner can call this function");
    });
  });
});
