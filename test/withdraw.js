describe("Withdrawal and Burning Interaction", function () {
    let GALAXER, galaxer, NebulaNotes, nebulaNotes, CosmicCrucible, cosmicCrucible, owner, addr1, addr2;

    beforeEach(async function () {
        [owner, addr1, addr2, _] = await ethers.getSigners();

        GALAXER = await ethers.getContractFactory("GALAXER");
        galaxer = await GALAXER.deploy();

        NebulaNotes = await ethers.getContractFactory("NebulaNotes");
        nebulaNotes = await NebulaNotes.deploy();

        CosmicCrucible = await ethers.getContractFactory("CosmicCrucible");
        cosmicCrucible = await CosmicCrucible.deploy(galaxer.address, nebulaNotes.address);

        // Mint GALAXER for user
        await galaxer.connect(owner).mint(addr1.address, ethers.utils.parseEther("1000000"));

        // User approves CosmicCrucible to spend GALAXER
        await galaxer.connect(addr1).approve(cosmicCrucible.address, ethers.utils.parseEther("1000000"));

        // User stakes GALAXER in CosmicCrucible
        await cosmicCrucible.connect(addr1).stakeTokens(ethers.utils.parseEther("1000"));
    });

    describe("Withdrawal and burning", function () {
        it("Should burn NebulaNotes when user withdraws GLXR from CosmicCrucible", async function () {
            // User mints NebulaNotes
            await nebulaNotes.connect(addr1).mint(addr1.address, ethers.utils.parseEther("1000"));

            // User withdraws GLXR from CosmicCrucible
            await cosmicCrucible.connect(addr1).withdrawTokens(ethers.utils.parseEther("500"));

            // Check that the NebulaNotes have been burned
            const userBalance = await nebulaNotes.balanceOf(addr1.address);
            expect(userBalance).to.equal(ethers.utils.parseEther("500"));
        });
    });
});
