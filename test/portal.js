const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Portal", function () {
    let Portal, portal, GALAXER, galaxer, CosmicCrucible, cosmicCrucible, owner, addr1, addr2, addr3;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3, _] = await ethers.getSigners();

        GALAXER = await ethers.getContractFactory("GALAXER");
        galaxer = await GALAXER.deploy();

        CosmicCrucible = await ethers.getContractFactory("CosmicCrucible");
        cosmicCrucible = await CosmicCrucible.deploy(galaxer.address);

        Portal = await ethers.getContractFactory("Portal");
        portal = await Portal.deploy(galaxer.address, cosmicCrucible.address);
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await portal.owner()).to.equal(owner.address);
        });

        it("Should set the right GALAXER token", async function () {
            expect(await portal.newToken()).to.equal(galaxer.address);
        });

        it("Should set the right CosmicCrucible staking contract", async function () {
            expect(await portal.staker()).to.equal(cosmicCrucible.address);
        });
    });

    describe("Claiming", function () {
        it("Should fail if claim window is closed", async function () {
            await portal.connect(owner).mintRemainingTokens();
            await expect(
                portal.connect(addr1).claimNewToken(60, ethers.utils.parseEther("1000"))
            ).to.be.revertedWith("TokenMigration: Claim window closed");
        });

        it("Should fail if user has already claimed", async function () {
            await portal.connect(owner).whitelistAddresses([addr1.address]);
            await portal.connect(addr1).claimNewToken(60, ethers.utils.parseEther("1000"));
            await expect(
                portal.connect(addr1).claimNewToken(60, ethers.utils.parseEther("1000"))
            ).to.be.revertedWith("TokenMigration: User has already claimed");
        });

        it("Should fail if user is not whitelisted", async function () {
            await expect(
                portal.connect(addr1).claimNewToken(60, ethers.utils.parseEther("1000"))
            ).to.be.revertedWith("TokenMigration: User is not whitelisted");
        });

        it("Should fail if mint amount exceeds max claim amount", async function () {
            await portal.connect(owner).whitelistAddresses([addr1.address]);
            await expect(
                portal.connect(addr1).claimNewToken(60, ethers.utils.parseEther("1000000000000"))
            ).to.be.revertedWith("TokenMigration: Claim amount exceeds maximum limit");
        });

        it("Should pass if all conditions are met", async function () {
            await portal.connect(owner).whitelistAddresses([addr1.address]);
            await portal.connect(addr1).claimNewToken(60, ethers.utils.parseEther("1000"));
            expect(await galaxer.balanceOf(cosmicCrucible.address)).to.equal(ethers.utils.parseEther("1000"));
        });
    });

    describe("Minting Remaining Tokens", function () {
        it("Should fail if claim window is already closed", async function () {
            await portal.connect(owner).mintRemainingTokens();
            await expect(
                portal.connect(owner).mintRemainingTokens()
            ).to.be.revertedWith("TokenMigration: Claim window already closed");
        });

        it("Should fail if there are no remaining tokens to mint", async function () {
            await expect(
                portal.connect(owner).mintRemainingTokens()
            ).to.be.revertedWith("TokenMigration: No remaining tokens to mint");
        });

        it("Should pass and mint remaining tokens to deployer's address", async function () {
            await galaxer.mint(portal.address, ethers.utils.parseEther("1000000000000"));
            await portal.connect(owner).mintRemainingTokens();
            expect(await galaxer.balanceOf(owner.address)).to.equal(ethers.utils.parseEther("1000000000000"));
        });
    });

    describe("Whitelisting Addresses", function () {
        it("Should fail if not called by owner", async function () {
            await expect(
                portal.connect(addr1).whitelistAddresses([addr1.address])
            ).to.be.revertedWith("Ownable: caller is not the owner");
        });

        it("Should pass and whitelist addresses if called by owner", async function () {
            await portal.connect(owner).whitelistAddresses([addr1.address, addr2.address, addr3.address]);
            expect(await portal.whitelisted(addr1.address)).to.equal(true);
            expect(await portal.whitelisted(addr2.address)).to.equal(true);
            expect(await portal.whitelisted(addr3.address)).to.equal(true);
        });
    });
});
