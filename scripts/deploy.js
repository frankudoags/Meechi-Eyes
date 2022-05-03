const hre = require("hardhat");

async function main() {
  
  const MeechiEyes = await hre.ethers.getContractFactory("MeechiEyes");
  const meechieyes = await MeechiEyes.deploy();

  await meechieyes.deployed();

  console.log("MEECHIEYES deployed to:", meechieyes.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
