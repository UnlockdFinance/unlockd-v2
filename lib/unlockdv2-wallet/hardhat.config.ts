import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-deploy";

dotenv.config();

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

let accounts: any[] = [];
if (process.env.PRIVATE_KEY !== undefined) {
  accounts = [process.env.PRIVATE_KEY];
} else {
  throw new Error(`PRIVATE_KEY not set`);
}

const config: HardhatUserConfig = {
  // solidity: "0.8.13",
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  paths: {
    artifacts: "./artifacts",
    sources: "./src",
  },
  networks: {
    goerli: {
      url: process.env.GOERLI_RPC || "",
      accounts: accounts,
    },
  },
  namedAccounts: {
    deployer: { default: 0 },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.YOUR_ETHERSCAN_API_KEY,
  },
};

export default config;
