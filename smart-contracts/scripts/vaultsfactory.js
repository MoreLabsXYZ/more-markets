const { ethers } = require("hardhat");

async function main() {
  const [owner] = await ethers.getSigners();

  // const vaultsFactory = await ethers.getContractAt("MoreVaultsFactory", "0xb21fa39418F3AbBAE407124896B84980E7149b3e");
  // await vaultsFactory.createMetaMorpho(
  //   // owner.address,
  //   "0x2690eef879df58b97ec7cf830f7627fb1b51f826",
  //   1000,
  //   "0xC4F1dFC005Cb2285b8A9Ede7c525b0eEdF24F5db",
  //   "doge vault",
  //   "dogevault",
  //   "0x4d434b564c543111000000000000000000000000000000000000000000000000"
  // )

  const tokenInfo = await ethers.getContractAt("ERC20Mock", "0xC4F1dFC005Cb2285b8A9Ede7c525b0eEdF24F5db");
  console.log(await tokenInfo.name());

  const vaultsFacotry = await ethers.getContractAt("MoreVaultsFactory", "0xb21fa39418F3AbBAE407124896B84980E7149b3e")

  const vaults = await vaultsFacotry.arrayOfMorphos();
  for (const vault of vaults) {
    console.log(vault);
    const vaultContract = await ethers.getContractAt("MoreVaults", vault);
    console.log("Asset: ", await vaultContract.asset());
  }

  // mint some doge
  {
    const dogeContract = await ethers.getContractAt("ERC20Mock", "0xC4F1dFC005Cb2285b8A9Ede7c525b0eEdF24F5db");
    const mintTx = await dogeContract.mint(owner.address, ethers.parseEther("100000"));
    await mintTx.wait();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});