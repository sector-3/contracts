import { ethers } from "hardhat";

async function main() {
  console.log('Deploying governance/Sector3Governor.sol')
  
  console.log('process.env.DEPLOYER_PRIVATE_KEY exists:', process.env.DEPLOYER_PRIVATE_KEY != undefined)
  console.log('process.env.ETHERSCAN_API_KEY exists:', process.env.ETHERSCAN_API_KEY != undefined)
  
  const Sector3Governor = await ethers.getContractFactory("Sector3Governor");
  const sector3Governor = await Sector3Governor.deploy('0x5FbDB2315678afecb367f032d93F642f64180aa3');

  await sector3Governor.deployed();

  console.log(`Sector3Governor deployed to ${sector3Governor.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
