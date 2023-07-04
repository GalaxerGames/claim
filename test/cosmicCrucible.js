const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NebulaNote", function () {
    let NebulaNote, nebulaNote, owner, addr1, addr2;

    beforeEach(async function () {
        NebulaNote = await ethers.getContractFactory("NebulaNote");
        [owner, addr1, addr2, _] = await ethers.getSigners();
        nebulaNote = await NebulaNote.deploy();
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await nebulaNote.owner()).to.equal(owner.address);
        });

        it("Should assign the total supply of tokens to the owner", async function () {
            const ownerBalance = await nebulaNote.balanceOf(owner.address);
            expect(await nebulaNote.totalSupply()).to.equal(ownerBalance);
        });
    });

    describe("Transactions", function () {
        it("Should fail if sender doesn’t have enough tokens", async function () {
            const initialOwnerBalance = await nebulaNote.balanceOf(owner.address);

            // Try to send 1 token from addr1 (0 tokens) to owner (1000 tokens).
            await expect(
                nebulaNote.connect(addr1).transfer(owner.address, 1)
            ).to.be.revertedWith("Not enough tokens");

            // Owner balance shouldn't have changed.
            expect(await nebulaNote.balanceOf(owner.address)).to.equal(
                initialOwnerBalance
            );
        });

        it("Should pass if sender has enough tokens", async function () {
            await nebulaNote.transfer(addr1.address, 500);
            const initialOwnerBalance = await nebulaNote.balanceOf(owner.address);
            await nebulaNote.connect(addr1).transfer(owner.address, 500);
            expect(await nebulaNote.balanceOf(owner.address)).to.equal(initialOwnerBalance + 500);
        });
    });

    describe("Gas usage", function () {
        it("Should not exceed gas limit for any transaction", async function () {
            const tx = await nebulaNote.transfer(addr1.address, 500);
            const receipt = await tx.wait();
            expect(receipt.gasUsed).to.be.lt(ethers.BigNumber.from("6000000")); // Example gas limit
        });
    });
});

describe("CosmicCrucible", function () {
    let CosmicCrucible, cosmicCrucible, owner, addr1, addr2, NebulaNote, nebulaNote;

    beforeEach(async function () {
        NebulaNote = await ethers.getContractFactory("NebulaNote");
        [owner, addr1, addr2, _] = await ethers.getSigners();
        nebulaNote = await NebulaNote.deploy();

        CosmicCrucible = await ethers.getContractFactory("CosmicCrucible");
        cosmicCrucible = await CosmicCrucible.deploy(nebulaNote.address);
    });

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            expect(await cosmicCrucible.owner()).to.equal(owner.address);
        });

        it("Should set the right NebulaNote token", async function () {
            expect(await cosmicCrucible.nebulaNote()).to.equal(nebulaNote.address);
        });
    });

    describe("Staking", function () {
        it("Should fail if user tries to stake more tokens than they have", async function () {
            await nebulaNote.transfer(addr1.address, 500);
            await expect(
                cosmicCrucible.connect(addr1).stake(600)
            ).to.be.revertedWith("Not enough tokens to stake");
        });

        it("Should pass if user stakes equal or less than their balance", async function () {
            await nebulaNote.transfer(addr1.address, 500);
            await cosmicCrucible.connect(addr1).stake(500);
            expect(await cosmicCrucible.balanceOf(addr1.address)).to.equal(500);
        });
    });

    describe("Gas usage", function () {
        it("Should not exceed gas limit for any transaction", async function () {
            await nebulaNote.transfer(addr1.address, 500);
            const tx = await cosmicCrucible.connect(addr1).stake(500);
            const receipt = await tx.wait();
            expect(receipt.gasUsed).to.be.lt(ethers.BigNumber.from("6000000")); // Example gas limit
        });
    });
});
