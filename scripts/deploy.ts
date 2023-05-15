import { ethers } from "hardhat";
import * as core from '@actions/core'
import { request } from "@octokit/request";
import dotenv from "dotenv"
dotenv.config();

async function deploy() {
  const Artwork = await ethers.getContractFactory("Artwork");
  // add constructor arguments if necessary
  const artwork = await Artwork.deploy();

  await artwork.deployed();

  console.log(
    `Artwork contract with deployed to ${artwork.address}`
  );
  core.exportVariable('SC_ADDRESS', artwork.address)

  // updating sc address in organizations variable
  const result = await request("PATCH /orgs/{org}/actions/variables/{name}", {
    headers: {
      authorization: process.env.UPDATE_SC_ADDRESS_TOKEN,
    },
    org: process.env.ARTIS_ORG_NAME as string,
    name: process.env.ARTIS_SC_VARIABLE_NAME as string,
    value: artwork.address
  });
  console.log("response of updating sc address in organization variable: " + result.data)

}

deploy().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
