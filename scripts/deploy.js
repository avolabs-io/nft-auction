async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const ERC721 = await ethers.getContractFactory("ERC721MockContract");
  const ERC20 = await ethers.getContractFactory("ERC20MockContract");
  const NFTAuction = await ethers.getContractFactory("NFTAuction");
  const nftAuction = await NFTAuction.deploy();
  const erc20 = await ERC20.deploy("Mock ERC20", "MER");

  const erc721 = await ERC721.deploy("New Mocks", "NMK");

  console.log("nftAuction address:", nftAuction.address);
  console.log("ERC20 Token address:", erc20.address);
  console.log("ERC721 Token address:", erc721.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
