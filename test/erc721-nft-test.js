const {expect} = require("chai");

describe("ERC721NFT", function () {
  it("It should deploy the contract, mint a token, and resolve to the right URI", async () => {
    const NFT = await ethers.getContractFactory("ERC721NFT");
    const nft = await NFT.deploy("NFTPort", "NFT");
    const URI = "ipfs://QmWJBNeQAm9Rh4YaW8GFRnSgwa4dN889VKm9poc2DQPBkv";
    await nft.deployed();
    await nft.mintToCaller("0xcc6CE1caF8D42ad3bf041f377f1F2C2FbC202b33", URI);
    expect(await nft.tokenURI(1)).to.equal(URI)
  });

  it("It should deploy the contract, with correct name and symbol", async () => {
    const NFT = await ethers.getContractFactory("ERC721NFT");
    const nft = await NFT.deploy("mock_name", "symbol");
    await nft.deployed();
    expect(await nft.name()).to.equal("mock_name")
    expect(await nft.symbol()).to.equal("symbol")
  });
});
