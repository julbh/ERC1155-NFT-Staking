const { expect } = require("chai");
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account: " + deployer.address);


  console.log("Deploy NodeERC1155 Token");
  const NODE = await ethers.getContractFactory('NodeERC1155');
  const node = await NODE.deploy();
  console.log("NodeERC1155 deployed on ", node.address);

  console.log("Deploy Cork Token");
  const CORK = await ethers.getContractFactory('CorkToken');
  const cork = await CORK.deploy(10000);
  console.log("Cork deployed on ", cork.address);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
