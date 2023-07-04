describe("Interaction between contracts", function () {
    let GALAXER, galaxer, NebulaNotes, nebulaNotes, CosmicCrucible, cosmicCrucible, Portal, portal, owner, addr1, addr2;

    beforeEach(async function () {
        [owner, addr1, addr2, _] = await ethers.getSigners();

        GALAXER = await ethers.getContractFactory("GALAXER");
        galaxer = await GALAXER.deploy();

        NebulaNotes = await ethers.getContractFactory("NebulaNotes");
        nebulaNotes = await NebulaNotes.deploy();

        CosmicCrucible = await ethers.getContractFactory("CosmicCrucible");
        cosmicCrucible = await CosmicCrucible.deploy(galaxer.address);

        Portal = await ethers.getContractFactory("Portal");
        portal = await Portal.deploy(galaxer.address, cosmicCrucible.address);
    });

    describe("Interactions", function () {
        it("Should allow user to mint GALAXER, claim new tokens via Portal, stake in CosmicCrucible, and interact with NebulaNotes", async function () {
            // Mint GALAXER for user
            await galaxer.connect(owner).mint(addr1.address, ethers.utils.parseEther("1000000"));

            // User approves Portal to spend GALAXER
            await galaxer.connect(addr1).approve(portal.address, ethers.utils.parseEther("1000000"));

            // Owner whitelists user
            await portal.connect(owner).whitelistAddresses([addr1.address]);

            // User claims new tokens via Portal
            await portal.connect(addr1).claimNewToken(60, ethers.utils.parseEther("1000"));

            // Check that GALAXER has been staked in CosmicCrucible
            expect(await cosmicCrucible.balanceOf(addr1.address)).to.equal(ethers.utils.parseEther("1000"));

            // User interacts with NebulaNotes (add NebulaNotes function calls here)
            // E.g. if user can create a note
            await nebulaNotes.connect(addr1).createNote("Test note");

            // Check that the note has been created
            expect(await nebulaNotes.notes(addr1.address)).to.equal("Test note");
        });
    });
});
