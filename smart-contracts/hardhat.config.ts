import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";
import "@nomicfoundation/hardhat-verify";
require("dotenv").config();

if (!process.env.MNEMONIC)
  throw new Error("Please set your MNEMONIC in a .env file");
let mnemonic = process.env.MNEMONIC as string;

if (!process.env.PRIVATE_KEY)
  throw new Error("Please set your PRIVATE_KEY in a .env file");
let privateKey = process.env.PRIVATE_KEY as string;

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-sepolia.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT",
        blockNumber: 6270166,
      },
      accounts: { count: 99 },
    },
    sepolia: {
      url: "https://rpc.sepolia.org",
      accounts: {
        count: 10,
        initialIndex: 0,
        mnemonic,
        path: "m/44'/60'/0'/0",
      },
    },
    bsc: {
      url: "https://bsc-dataseed1.defibit.io/",
      accounts: privateKey !== undefined ? [privateKey] : [],
      gasPrice: 1 * 10 ** 9,
    },
    flow: {
      url: "https://testnet.evm.nodes.onflow.org",
      accounts: [privateKey], // In practice, this should come from an environment variable and not be commited
      gas: 500000, // Example gas limit
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.21",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true,
          evmVersion: "paris",
        },
      },
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 4000,
          },
          viaIR: true,
          evmVersion: "paris",
        },
      },
      {
        version: "0.8.13",
        settings: {
          optimizer: {
            enabled: true,
            runs: 4000,
          },
          viaIR: true,
          evmVersion: "paris",
        },
      },
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 4000,
          },
          viaIR: true,
          evmVersion: "paris",
        },
      },
    ],
  },
  gasReporter: {
    enabled: true,
  },
  etherscan: {
    apiKey: {
      // Is not required by blockscout. Can be any non-empty string
      flow: "abc",
    },
    customChains: [
      {
        network: "flow",
        chainId: 545,
        urls: {
          apiURL: "https://evm-testnet.flowscan.io/api",
          browserURL: "https://evm-testnet.flowscan.io/",
        },
      },
    ],
  },
  sourcify: {
    enabled: false,
  },
};

export default config;
