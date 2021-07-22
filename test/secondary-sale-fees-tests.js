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
describe("Test Secondary Sale and fees", function () {
  let ERC721;
  let erc721;
  let NFTAuction;
  let nftAuction;
  let contractOwner;
  let user1;
  let user2;
  let user3;
  let user4;
  let testPlatform;
  let testArtist;
  let bidIncreasePercentage;
  let auctionBidPeriod;
  let feeRecipients;
  let feePercentages;

  //deploy mock erc721 token
  beforeEach(async function () {
    ERC721 = await ethers.getContractFactory("ERC721MockContract");
    NFTAuction = await ethers.getContractFactory("NFTAuction");
    [ContractOwner, user1, user2, user3, user4, testPlatform, testArtist] =
      await ethers.getSigners();

    erc721 = await ERC721.deploy("my mockables", "MBA");
    await erc721.deployed();
    await erc721.mint(user1.address, 1);

    nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();
    //approve our smart contract to transfer this NFT
    await erc721.connect(user1).approve(nftAuction.address, 1);
  });
  it("should allow multiple bids and conclude auction after end period", async function () {
    bidIncreasePercentage = 2000;
    auctionBidPeriod = 106400;
    feeRecipients = [testPlatform.address];
    feePercentages = [1000];
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
        feeRecipients,
        feePercentages
      );
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

    let testPlatformBalanceBeforePayout = await testPlatform.getBalance();
    let platformAmount = BigNumber.from(testPlatformBalanceBeforePayout).add(
      BigNumber.from((bidIncreaseByMinPercentage3 * 1000) / 10000)
    );
    await nftAuction.connect(user3).settleAuction(erc721.address, tokenId);
    expect(await erc721.ownerOf(tokenId)).to.equal(user3.address);

    let platformBal = await testPlatform.getBalance();
    await expect(BigNumber.from(platformBal).toString()).to.be.equal(
      platformAmount
    );

    let feeRecipients2 = [user1.address, testPlatform.address];
    let feePercentages2 = [1000, 100];
    await erc721.connect(user3).approve(nftAuction.address, tokenId);
    //user 3 now to create an auction specifying user 1 and the platform as fee recipients
    await nftAuction
      .connect(user3)
      .createNewNftAuction(
        erc721.address,
        tokenId,
        zeroAddress,
        bidIncreaseByMinPercentage3,
        buyNowPrice,
        auctionBidPeriod,
        bidIncreasePercentage,
        feeRecipients2,
        feePercentages2
      );

    await nftAuction
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
      );

    await network.provider.send("evm_increaseTime", [auctionBidPeriod + 1]);
    //auction has ended\
    let testPlatformBalanceBeforePayout2 = await testPlatform.getBalance();
    let testArtistBalanceBeforePayout2 = await user1.getBalance(); //user 1 was the artist
    let user3BalanceBeforePayout = await user3.getBalance();

    await nftAuction.connect(user2).settleAuction(erc721.address, tokenId);
    expect(await erc721.ownerOf(tokenId)).to.equal(user4.address);
    let artistBal2 = await user1.getBalance();
    let platformBal2 = await testPlatform.getBalance();
    let user3Bal = await user3.getBalance();
    let platformAmount2 = BigNumber.from(platformBal2).sub(
      BigNumber.from(testPlatformBalanceBeforePayout2)
    );
    let artistAmount2 = BigNumber.from(artistBal2).sub(
      BigNumber.from(testArtistBalanceBeforePayout2)
    );
    let user3Amount = BigNumber.from(user3Bal).sub(
      BigNumber.from(user3BalanceBeforePayout)
    );
    let total = platformAmount2.add(artistAmount2).add(user3Amount);

    await expect(total.toString()).to.be.equal(
      BigNumber.from(bidIncreaseByMinPercentage4).toString()
    );
  });
});
