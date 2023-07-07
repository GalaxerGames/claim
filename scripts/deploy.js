const { ethers } = require("hardhat")

async function main() {
  // const NebulaNote = await ethers.getContractFactory("NebulaNote");
  // const nebulaNote = await NebulaNote.deploy()
  // console.log("NebulaNote Address: ", nebulaNote.address);

  const GLXRStaker = await ethers.getContractFactory("MockGLXRStaker");
  const _GLXRStaker = await GLXRStaker.deploy("0x2Ea4B3a79a741Dd6C81e61D88BDa861C5E2120Cc")
  console.log("GLXRStaker Address: ", _GLXRStaker.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
