const { expect } = require("chai");
const { ethers } = require("hardhat");

const { BigNumber } = require("ethers");
// Enable and inject BN dependency

const tokenId = 1;
const minPrice = 100;
const newMinPrice = 50;
const buyNowPrice = 100000;
const auctionBidPeriod = 86400; //seconds
const bidIncreasePercentage = 1000;
const highBidIncreasePercentage = 2500;
const zeroAddress = "0x0000000000000000000000000000000000000000";
const zeroERC20Tokens = 0;
const emptyFeeRecipients = [];
const emptyFeePercentages = [];

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
    await erc721.mint(user1.address, tokenId);

    nftAuction = await NFTAuction.deploy();
    await nftAuction.deployed();
    //approve our smart contract to transfer this NFT
    await erc721.connect(user1).approve(nftAuction.address, tokenId);
  });

  describe("Test make bids and bid requirements", function () {
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
    // 1 basic test, NFT put up for auction can accept bids with ETH
    it("Calling makeBid to bid on new NFTAuction", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: minPrice,
        });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.nftHighestBidder).to.equal(user2.address);
      expect(result.nftHighestBid.toString()).to.be.equal(
        BigNumber.from(minPrice).toString()
      );
    });
    it("Should transfer NFT to contract if bid meets min Price", async function () {
      expect(await erc721.ownerOf(tokenId)).to.equal(user1.address);
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: minPrice,
        });
      expect(await erc721.ownerOf(tokenId)).to.equal(nftAuction.address);
    });
    it("should revert if owner transfer nft and minPrice is met", async function () {
      await erc721.connect(user1).approve(user2.address, tokenId);
      await erc721
        .connect(user1)
        .transferFrom(user1.address, user2.address, tokenId);
      expect(await erc721.ownerOf(tokenId)).to.equal(user2.address);
      await expect(
        nftAuction
          .connect(user2)
          .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
            value: minPrice,
          })
      ).to.be.revertedWith("Seller doesn't own NFT");
    });
    it("should revert if owner removes contract approval and minPrice is met", async function () {
      await erc721.connect(user1).approve(zeroAddress, tokenId);
      await expect(
        nftAuction
          .connect(user2)
          .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
            value: minPrice,
          })
      ).to.be.revertedWith("ERC721: transfer caller is not owner nor approved");
    });
    it("should revert if owner transfer nft and minPrice is met", async function () {
      await erc721.connect(user1).approve(user2.address, tokenId);
      await erc721
        .connect(user1)
        .transferFrom(user1.address, user2.address, tokenId);
      expect(await erc721.ownerOf(tokenId)).to.equal(user2.address);
      await expect(
        nftAuction
          .connect(user2)
          .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
            value: minPrice,
          })
      ).to.be.revertedWith("Seller doesn't own NFT");
    });
    it("should ensure owner cannot bid on own NFT", async function () {
      await expect(
        nftAuction
          .connect(user1)
          .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
            value: minPrice,
          })
      ).to.be.revertedWith("Owner cannot bid on own NFT");
    });

    it("should not allow bid lower than minimum bid percentage", async function () {
      nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, 0, {
          value: minPrice,
        });
      await expect(
        nftAuction
          .connect(user3)
          .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
            value: (minPrice * 10100) / 10000,
          })
      ).to.be.revertedWith("Not enough funds to bid on NFT");
    });

    it("should allow for new bid if higher than minimum percentage", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: minPrice,
        });
      const bidIncreaseByMinPercentage =
        (minPrice * (10000 + bidIncreasePercentage)) / 10000;
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: bidIncreaseByMinPercentage,
        });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.nftHighestBidder).to.equal(user3.address);
      expect(result.nftHighestBid.toString()).to.be.equal(
        BigNumber.from(bidIncreaseByMinPercentage).toString()
      );
    });

    it("should not allow bidder to withdraw if min price exceeded", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: minPrice,
        });
      await expect(
        nftAuction.connect(user2).withdrawBid(erc721.address, tokenId)
      ).to.be.revertedWith("The auction has a valid bid made");
    });

    it("should allow bidder to specify NFT recipient", async function () {
      await nftAuction
        .connect(user2)
        .makeCustomBid(
          erc721.address,
          tokenId,
          zeroAddress,
          zeroERC20Tokens,
          user3.address,
          {
            value: minPrice,
          }
        );
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.nftRecipient).to.be.equal(user3.address);
      expect(result.nftHighestBid.toString()).to.be.equal(
        BigNumber.from(minPrice).toString()
      );
    });
    it("should not allow user to specify 0 address as recipient", async function () {
      await expect(
        nftAuction
          .connect(user2)
          .makeCustomBid(
            erc721.address,
            tokenId,
            zeroAddress,
            minPrice,
            zeroAddress,
            {
              value: minPrice,
            }
          )
      ).to.be.revertedWith("Cannot specify 0 address");
    });

    it("should allow bidder to buy NFT by meeting buyNowPrice", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: buyNowPrice,
        });
      expect(await erc721.ownerOf(tokenId)).to.equal(user2.address);
    });
    it("should reset auction if buyNowPrice met", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: buyNowPrice,
        });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.minPrice.toString()).to.be.equal(
        BigNumber.from(0).toString()
      );
      expect(result.buyNowPrice.toString()).to.be.equal(
        BigNumber.from(0).toString()
      );
      expect(result.nftSeller).to.be.equal(zeroAddress);
    });
    it("should allow seller take highestbid and conclude auction", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: minPrice,
        });
      const bidIncreaseByMinPercentage =
        (minPrice * (10000 + bidIncreasePercentage)) / 10000;
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: bidIncreaseByMinPercentage,
        });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.auctionEnd).to.be.not.equal(BigNumber.from(0));
      await nftAuction.connect(user1).takeHighestBid(erc721.address, tokenId);
      result = await nftAuction.nftContractAuctions(erc721.address, tokenId);
      expect(result.auctionEnd).to.be.equal(BigNumber.from(0));
      expect(await erc721.ownerOf(tokenId)).to.be.equal(user3.address);
    });
    it("should allow seller update buyNowPrice and conclude auction", async function () {
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: minPrice,
        });
      const bidIncreaseByMinPercentage =
        (minPrice * (10000 + highBidIncreasePercentage)) / 10000;
      await nftAuction
        .connect(user3)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: bidIncreaseByMinPercentage,
        });
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.auctionEnd).to.be.not.equal(BigNumber.from(0));
      await nftAuction
        .connect(user1)
        .updateBuyNowPrice(erc721.address, tokenId, bidIncreaseByMinPercentage);
      result = await nftAuction.nftContractAuctions(erc721.address, tokenId);
      expect(result.auctionEnd).to.be.equal(BigNumber.from(0));
      expect(await erc721.ownerOf(tokenId)).to.be.equal(user3.address);
    });
  });
  describe("Test underbid functionality", function () {
    let underBid = minPrice - 10;
    let result;
    let user2BalanceBeforePayout;
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
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: underBid,
        });
      result = await nftAuction.nftContractAuctions(erc721.address, tokenId);
      user2BalanceBeforePayout = await user2.getBalance();
    });
    it("should allow underbidding", async function () {
      expect(result.nftHighestBidder).to.be.equal(user2.address);
      expect(result.nftHighestBid.toString()).to.be.equal(
        BigNumber.from(underBid).toString()
      );
    });
    it("should not commence the auction", async function () {
      expect(result.auctionEnd).to.be.equal(BigNumber.from(0).toString());
    });
    it("should set a minimum price", async function () {
      expect(result.minPrice).to.be.equal(BigNumber.from(minPrice).toString());
    });
    it("should reset bids when bidder withdraws funds", async function () {
      await nftAuction.connect(user2).withdrawBid(erc721.address, tokenId);
      result = await nftAuction.nftContractAuctions(erc721.address, tokenId);
      expect(result.nftHighestBidder).to.be.equal(zeroAddress);
    });
    it("should transfer the correct amount to the bidder if they withdraw", async function () {
      const gasPrice = 1;
      const tx = await nftAuction
        .connect(user2)
        .withdrawBid(erc721.address, tokenId, { gasPrice: gasPrice });
      const txResponse = await tx.wait();
      const receipt = await ethers.provider.getTransactionReceipt(
        txResponse.transactionHash
      );
      const gasUsed = receipt.gasUsed;
      const gasUsedBN = BigNumber.from(gasUsed);
      const gasCost = BigNumber.from(gasPrice).mul(gasUsedBN);

      const balBefore = BigNumber.from(user2BalanceBeforePayout);
      const amount = BigNumber.from(underBid);
      // multiply gas cost by gas used
      const expectedBalanceAfterPayout = balBefore.add(amount).sub(gasCost);
      //confirm that the user gets their withdrawn bid minus the gas cost
      const userBalance = await user2.getBalance();
      expect(userBalance.toString()).to.be.equal(
        expectedBalanceAfterPayout.toString()
      );
    });
    it("should not allow other users to withdraw underbid", async function () {
      await expect(
        nftAuction.connect(user3).withdrawBid(erc721.address, tokenId)
      ).to.be.revertedWith("Cannot withdraw funds");
    });
    it("should allow seller to lower minimum price and start the auction", async function () {
      await nftAuction
        .connect(user1)
        .updateMinimumPrice(erc721.address, tokenId, newMinPrice);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.auctionEnd.toString()).to.be.not.equal(
        BigNumber.from(0).toString()
      );
    });
    it("should allow seller to update price above current bid and not start the auction", async function () {
      await nftAuction
        .connect(user1)
        .updateMinimumPrice(erc721.address, tokenId, underBid + 5);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );

      expect(result.auctionEnd.toString()).to.be.equal(
        BigNumber.from(0).toString()
      );
      expect(result.nftHighestBid.toString()).to.be.equal(
        BigNumber.from(underBid).toString()
      );
    });
  });
  describe("Test make bid attacks", function () {
    let Attacker;
    let attack;
    beforeEach(async function () {
      Attacker = await ethers.getContractFactory("attackerContract");
      attack = await Attacker.deploy();
      await attack.deployed();
      attack.setAuctionContract(nftAuction.address);
      attack.connect(user1).deposit({ value: 100000 });
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
    it("should allow user to still bid after attack contract reverts in receive method", async function () {
      attack.bidOnAuction(erc721.address, tokenId, minPrice);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.nftHighestBidder).to.be.equal(attack.address);
      await nftAuction
        .connect(user2)
        .makeBid(erc721.address, tokenId, zeroAddress, zeroERC20Tokens, {
          value: buyNowPrice,
        });
      expect(await erc721.ownerOf(tokenId)).to.equal(user2.address);
      let attackBal = await attack.balanceOfContract();
      expect(attackBal.toString()).to.be.equal(
        BigNumber.from(99900).toString()
      );
      await expect(attack.withdrawFailed()).to.be.revertedWith(
        "withdraw failed"
      );
      attackBal = await attack.balanceOfContract();
      expect(attackBal.toString()).to.be.equal(
        BigNumber.from(99900).toString()
      );
      attack.setRequire(true);
      await attack.withdrawFailed();
      attackBal = await attack.balanceOfContract();
      expect(attackBal.toString()).to.be.equal(
        BigNumber.from(100000).toString()
      );
    });
    it("should not allow attack contract to withdraw more than once", async function () {
      attack.bidOnAuction(erc721.address, tokenId, minPrice - 2);
      let result = await nftAuction.nftContractAuctions(
        erc721.address,
        tokenId
      );
      expect(result.nftHighestBidder).to.be.equal(attack.address);
      expect(result.auctionEnd.toString()).to.be.equal(
        BigNumber.from(0).toString()
      );
      attack.setRequire(true);
      let attackBal = await attack.balanceOfContract();
      expect(attackBal.toString()).to.be.equal(
        BigNumber.from(99902).toString()
      );
      await attack.withdraw();
      attackBal = await attack.balanceOfContract();
      expect(attackBal.toString()).to.be.equal(
        BigNumber.from(99902).toString()
      );
    });
  });
});
