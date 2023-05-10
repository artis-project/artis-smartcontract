import { ethers } from "hardhat";
import * as core from '@actions/core'

async function deploy() {
  const Artwork = await ethers.getContractFactory("Artwork");
  // add constructor arguments if necessary
  const artwork = await Artwork.deploy();

  await artwork.deployed();

  console.log(
    `Artwork contract with deployed to ${artwork.address}`
  );
  core.exportVariable('SC_ADDRESS', artwork.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
deploy().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
