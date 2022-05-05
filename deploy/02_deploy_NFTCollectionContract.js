module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("NFTCollectionContract", {
    from: deployer,
    log: true,
    args: [
      {
        owner: deployer,
        name: "NFTCollection",
        symbol: "NFT",
        maxSupply: 1000,
        reservedSupply: 0,
        tokensPerMint: 10,
        mintPrice: ethers.utils.parseEther("0.01"),
        treasuryAddress: deployer,
      },
      {
        baseURI: "",
        prerevealTokenURI: "",
        publicMintStart: 0,
        presaleMintStart: 0,
        presaleMerkleRoot: ethers.utils.hexZeroPad("0x00", 32),
        metadataUpdatable: true,
        royaltiesBps: 250,
        royaltiesAddress: deployer,
      },
    ],
  });
};

module.exports.tags = ["Standalone"];
