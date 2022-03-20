const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("test start", function () {
  let NODE;
  let node;
  let CORK;
  let cork;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  before(async function () {
    [owner] = await ethers.getSigners();

    NODE = await ethers.getContractFactory("NodeERC1155");
    CORK = await ethers.getContractFactory("CorkToken");

    node = await NODE.deploy();
    cork = await CORK.deploy(10000);
  });

  //
  describe("Deploy init", function () {
    it("Should set the right node and cork", async function () {
      await node.setCorkAddr(cork.address);
      await cork.setNode(node.address);
      expect(await node.corkAddr()).to.equal(cork.address);
      expect(await cork.nodeAddress()).to.equal(node.address);
    });
  });

  // describe("Buying a node", function () {
  //   it("Should buy a node", async function () {
  //     console.log("ownd", owner.address);
  //     await node.mint(owner.address, 0, "");
  //     let nodeState = await node.getNodeState(1);
  //     expect(nodeState.purchaser).to.equal(owner);
  //   });
  // });

  // describe("Transactions", function () {
  //   it("MT token Set vault", async function () {
  //     await mt.setVault(mintContract.address);
  //     expect(await mt.vault()).to.equal(mintContract.address);
  //   });

  //   it("BT token Mint", async function () {
  //     await bt.initVault(owner.address);
  //     await bt.mint( owner.address, initialMint );
  //     expect(await bt.balanceOf(owner.address)).to.equal(initialMint);
  //   });

  //   it("Owner approve BT", async function () {
  //     await bt.approve( mintContract.address, initialMint );
  //     expect(await bt.allowance(owner.address, mintContract.address)).to.equal(initialMint);
  //   });

  //   it("final test", async function () {
  //     await mt.setVault(mintContract.address);
  //     expect(await mt.vault()).to.equal(mintContract.address);
      
  //     await bt.initVault(owner.address);
  //     await bt.mint( owner.address, initialMint );
  //     expect(await bt.balanceOf(owner.address)).to.equal(initialMint);

  //     await bt.approve( mintContract.address, initialMint );
  //     expect(await bt.allowance(owner.address, mintContract.address)).to.equal(initialMint);
      
  //     await mintContract.mint("9");
  //     expect(await mt.balanceOf(owner.address)).to.equal('9000000000');

  //   });
    
  // });
});
