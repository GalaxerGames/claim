const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GALAXER Contract", function() {
  let GALAXER, galaxer, owner, addr1, addr2, addrs;
  let minterRole, pauserRole, blacklistedRole;

  beforeEach(async function () {
    GALAXER = await ethers.getContractFactory("GALAXER");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    galaxer = await GALAXER.deploy();
    await galaxer.deployed();

    // initialize the contract
    await galaxer.initialize();

    minterRole = await galaxer.MINTER_ROLE();
    pauserRole = await galaxer.PAUSER_ROLE();
    blacklistedRole = await galaxer.BLACKLISTED_ROLE();
  });

  describe("Deployment and Initialization", function() {
    it("Should set the right roles to the owner", async function () {
      expect(await galaxer.hasRole(minterRole, owner.address)).to.equal(true);
      expect(await galaxer.hasRole(pauserRole, owner.address)).to.equal(true);
    });
  });

  describe("Minting Tokens", function() {
    it("Should mint tokens when called by minter", async function () {
      await galaxer.mint(addr1.address, ethers.utils.parseEther("500"));
      expect(await galaxer.balanceOf(addr1.address)).to.equal(ethers.utils.parseEther("500"));
    });

    it("Shouldn't mint tokens that exceed max supply", async function () {
      const maxSupply = await galaxer.MAX_SUPPLY();

      // First, we mint the max supply
      await galaxer.mint(addr1.address, maxSupply);
      
      // Then, try to mint 1 additional token which should fail
      await expect(galaxer.mint(addr2.address, ethers.utils.parseEther("1"))).to.be.revertedWith("ERC20: minting would exceed max supply");
    });

    it("Shouldn't mint tokens when not called by minter", async function () {
      await expect(galaxer.connect(addr1).mint(addr1.address, ethers.utils.parseEther("500"))).to.be.revertedWith("AccessControl: account 1 is missing role 1.");
    });
  });

  describe("Blacklisting Accounts", function() {
    it("Should blacklist and unblacklist an account", async function () {
      // Blacklist addr1
      await galaxer.blacklist(addr1.address);
      expect(await galaxer.hasRole(blacklistedRole, addr1.address)).to.equal(true);

      // Unblacklist addr1
      await galaxer.unblacklist(addr1.address);
      expect(await galaxer.hasRole(blacklistedRole, addr1.address)).to.equal(false);
    });
  });

  describe("Transferring Tokens", function() {
    it("Should allow transfer when not paused and not blacklisted", async function () {
      await galaxer.mint(addr1.address, ethers.utils.parseEther("1000"));
      await galaxer.connect(addr1).transfer(addr2.address, ethers.utils.parseEther("500"));
      expect(await galaxer.balanceOf(addr2.address)).to.equal(ethers.utils.parseEther("500"));
    });

    it("Shouldn't allow transfer when paused", async function () {
      await galaxer.mint(addr1.address, ethers.utils.parseEther("1000"));
      await galaxer.pause();

      await expect(galaxer.connect(addr1).transfer(addr2.address, ethers.utils.parseEther("500"))).to.be.revertedWith("ERC20Pausable: token transfer while paused");
    });

    it("Shouldn't allow transfer when sender is blacklisted", async function () {
      await galaxer.mint(addr1.address, ethers.utils.parseEther("1000"));
      await galaxer.blacklist(addr1.address);

      await expect(galaxer.connect(addr1).transfer(addr2.address, ethers.utils.parseEther("500"))).to.be.revertedWith("ERC20Blacklist: sender account is blacklisted");
    });

    it("Shouldn't allow transfer when recipient is blacklisted", async function () {
      await galaxer.mint(addr1.address, ethers.utils.parseEther("1000"));
      await galaxer.blacklist(addr2.address);

      await expect(galaxer.connect(addr1).transfer(addr2.address, ethers.utils.parseEther("500"))).to.be.revertedWith("ERC20Blacklist: recipient account is blacklisted");
    });
  });
});
