# nft-auction

Smart contracts that allow the flexible auction of NFTs

[![Tests pass](https://github.com/avolabs-io/nft-auction/actions/workflows/main.yml/badge.svg)](https://github.com/avolabs-io/nft-auction/actions/workflows/main.yml)

```

```

## Coverage

- | File                      | % Stmts    | % Branch   | % Funcs    | % Lines    | Uncovered Lines  |
  | ------------------------- | ---------- | ---------- | ---------- | ---------- | ---------------- |
  | contracts/                | 100        | 100        | 100        | 100        |                  |
  | NFTAuction.sol            | 100        | 100        | 100        | 100        |                  |
  | ------------------------- | ---------- | ---------- | ---------- | ---------- | ---------------- |
  | All files                 | 100        | 100        | 100        | 100        |                  |
  | ------------------------- | ---------- | ---------- | ---------- | ---------- | ---------------- |

## outBID Auctions

This repository contains the smart contracts source code for the outBID Auction Protocol (name subject to change). The repository uses Hardhat as development enviroment for compilation, testing and deployment tasks.

## How does the outBID auction functionality work?

The open source smart contract can be easily used in a permissionless and flexible manner to auction (or simply buy/sell) NFTs. Sellers and bidders are able to make customized auctions and bids that allow for a holistic NFT auction/sale mechanism.

# NFT sellers can perform the following actions to sell or auction their NFTs:

- Create an auction for their single NFT and customize their auction by specifying the following:
  - The accepted payment type (ETH or any ERC20 token)
  - The minimum price of the auction (when this is met, the auction begins and users have a specific time to make a subsequent higher bid). If the buy now price is also set, the minimum price cannot be greater than 80% of the buy now price.
  - A buy now price, which when met by a buyer will automatically conclude the auction. The seller can set this value to zero, in which case the auction will only end when the minimum price is met and the auction bid period has concluded.
  - The auction bid period, which specifies the amount of time the auction will last after the minimum price is met. Every time a higher bid is then met, the auction will continue again for this time. For example, if auction bid period is set to x, and the minimum price is met at time T0, the auction will conclude at time T0+x. However, if at time T1 (where T0 < T1 < T0+x) a higher bid is made by another bidder, then the auction end time will update to be at time T1 +x.
  - A bid increase percentage (specified in basis points of 10000), which determines the amount a bidder must deposit in order to become the highest bidder. Therefore, if a bid of X amount is made, the next bidder must make a bid of X + ((X\*bid increase percentage)/10000).
  - An array of fee recipient addresses who will receive a percentage of the selling price of an auction when the auction is concluded.
  - An array of fee percentages (each in basis points of 10000) which must match the number of fee recipients. This determines the split of the selling price for each fee recipient.
- Create a default auction, which accepts all of the above parameters except for the bid increase percentage and auction bid period. These values are defaulted to the following:
- Create a batch NFT auction. These auctions can be customized as the above auctions for single NFTs, however the seller can specify an array of NFT token IDs (between 2 and 100 NFTs). The first token ID in the array is then used as the identifier of the auction.
- Create a sale for a single NFT or a batch of NFTs by specifying the following for each sale:
  - The accepted payment type (ETH or any ERC20 token)
  - The buy now price, which will conclude the sale when a buyer meets this price.
  - A whitelisted buyer address, which, when specified, allows only this address to purchase this NFT or this batch of NFTs.
  - An array of fee recipient addresses who will receive a percentage of the selling price of an auction when the auction is concluded.
  - An array of fee percentages (each in basis points of 10000) which must match the number of fee recipients. This determines the split of the selling price for each fee recipient.

# Bidders can perform the following actions using the outBID auction contract:

- Make a bid on an NFT or batch of NFTs put up for auction by specifying the following:
  - The amount of the bid (in either ETH or ERC20 Token as specified by the NFT seller). The bidder must make a bid that is higher by the bid increase percentage if another bid has already been made. However if this is met the bidder does not have to make a bid higher than the minimum price set by the seller(in this case, the auction would not start). Therefore, if no bid has been made on auction, the bidder can specify any amount.
  - The user can also make a custom bid and specify the NFT recipient who will receive the NFT or batch of NFTs if their bid is successful.
- Purchase an NFT or batch of NFTs put up for sale by specifying the following:
  - The amount of ERC20 Token or ETH (as specified by the seller). In this scenario, the purchaser can make an underbid of the buy now price, which will not conclude the sale. The amount sent by the purchaser must then be the default percentage higher than the previous underbid. If the purchaser specifies an amount equal to or greater than the buy now price, the sale is concluded and the NFT and purchase amount are transferred.

Users can also make early bids on single NFTs. This allows users to bid on an NFT even if the owner has not yet set it for auction or sale. The user can only specify an early bid in an ETH amount.

# Additional functions available:

Sellers can:

- Withdraw their NFT or batch of NFTs if the minimum price of the auction has not yet been met, or at anytime when put up for sale as long as the buy now price has not yet been met (in this case, the seller would not be the owner of the NFT as it would be tranferred to the highest bidder or their specified recipient).
- Update the whitelisted buyer in the case of a sale.
- Update the minimum price of the auction. This can only be done if no bid has been made that already exceeds the original minimum price. The new minimum price is still limited to 80% of the buy now price if set. if an underbid has been made on auction, and this update would mean that the minimum price is met by that underbid, then the auction would begin.
- Update the buy now price of the auction or sale. In the case of an auction the buy now price cannot be set to an amount which would make the minimum price greater than 80% of the buy now price. If a bid has been made on an auction or sale, and this update would mean that this bid now meets the buy now price, then the auction or sale would be concluded and the NFT and bid amount would be distributed accordingly.
- Take the highest bid amount and conclude the auction or sale.

Bidders can:

- Withdraw their bid on auction or sale if the minimum price of the auction has not been met, or in the case of an underbid on a sale.

* In the case of an auction where the auction bid period has expired (where the minimum bid has been met). Then any user can settle the auction and distribute the bid and NFT to the respective seller and recipient.
* Any user can also query the owner of a deposited NFT.
* In the case where the distribution of a bid amount has failed, the recipient of that amount can reclaim their failed credits.

## Development

First clone this repository and enter the directory.

Install dependencies:

```
$ yarn
```

## Testing

We use [Hardhat](https://hardhat.dev) and [hardhat-deploy](https://github.com/wighawag/hardhat-deploy)

To run integration tests:

```sh
$ yarn test
```

To run coverage:

```sh
$ yarn coverage
```

To deploy to Rinkeby:
create a secretManager.js containing the required private keys then run:

```sh
$ yarn deploy-rinkeby
```

## Expected Gas Costs

Assuming a gas price of 30 gwei. Batch auction testing for 10 NFTs.

                  Solc version: 0.8.4                  |  Optimizer enabled: true  |  Runs: 200  |  Block limit: 12450000 gas

| Contract    | Method                       | Min        | Max     | Avg    | # calls | usd (avg) |
| ----------- | ---------------------------- | ---------- | ------- | ------ | ------- | --------- |
| NFTAuction  | createBatchNftAuction        | 784175     | 792328  | 787797 | 9       | 55.38     |
|             |                              |            |         |        |         |           |
| NFTAuction  | createBatchSale              | 715916     | 741696  | 735240 | 27      | 51.68     |
|             |                              |            |         |        |         |           |
| NFTAuction  | createDefaultBatchNftAuction | 727579     | 753432  | 745725 | 12      | 52.42     |
|             |                              |            |         |        |         |           |
| NFTAuction  | createDefaultNftAuction      | 109232     | 244593  | 144694 | 30      | 10.17     |
|             |                              |            |         |        |         |           |
| NFTAuction  | createNewNftAuction          | 170433     | 259239  | 183445 | 52      | 12.89     |
|             |                              |            |         |        |         |           |
| NFTAuction  | createSale                   | 98073      | 232042  | 125443 | 33      | 8.82      |
|             |                              |            |         |        |         |           |
| NFTAuction  | makeBid                      | 60076      | 220748  | 106598 | 117     | 7.49      |
|             |                              |            |         |        |         |           |
| NFTAuction  | makeCustomBid                | 73820      | 230985  | 133375 | 11      | 9.38      |
|             |                              |            |         |        |         |           |
| NFTAuction  | settleAuction                | 63926      | 188527  | 112005 | 11      | 7.87      |
|             |                              |            |         |        |         |           |
| NFTAuction  | takeHighestBid               | 65469      | 71359   | 68414  | 2       | 4.81      |
|             |                              |            |         |        |         |           |
| NFTAuction  | updateBuyNowPrice            | 38458      | 73133   | 54323  | 4       | 3.82      |
|             |                              |            |         |        |         |           |
| NFTAuction  | updateMinimumPrice           | 39658      | 65972   | 48429  | 6       | 3.40      |
|             |                              |            |         |        |         |           |
| NFTAuction  | updateWhitelistedBuyer       | 30711      | 57606   | 38693  | 9       | 2.72      |
|             |                              |            |         |        |         |           |
| NFTAuction  | withdrawBid                  | 24233      | 28729   | 25733  | 6       | 1.81      |
|             |                              |            |         |        |         |           |
| NFTAuction  | withdrawNft                  | 49746      | 172355  | 139670 | 16      | 9.82      |
|             |                              |            |         |        |         |           |
| Deployments |                              | % of limit |
|             |                              |            |         |        |         |
| NFTAuction  | -                            | -          | 3455293 | 27.8 % | 242.88  |
