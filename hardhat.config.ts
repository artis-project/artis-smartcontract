import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv"
dotenv.config();


const config: HardhatUserConfig = {
  solidity: "0.8.18",
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  networks: {
    sepolia: {
      url: process.env.ALCHEMY_PROVIDER_URL,
      accounts: [ process.env.SMARTCONTRACT_ADMIN_PRIVATE_KEY as string ]
    }
  }
};

export default config;
