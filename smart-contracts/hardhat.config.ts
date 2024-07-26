import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";
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
    ],
  },
  gasReporter: {
    enabled: true,
  },
};

export default config;
