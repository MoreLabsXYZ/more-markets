import { getDefaultConfig, Chain } from "@rainbow-me/rainbowkit";
import type { NextPage } from "next";
import Head from "next/head";
import { useState, useEffect, ReactNode } from "react";
import TextField from "@mui/material/TextField";
import Button from "@mui/material/Button";
import Box from "@mui/material/Box";
import styles from "../styles/Home.module.css";
import {
  useWriteContract,
  useAccount,
  useAccountEffect,
  useChainId,
} from "wagmi";
import { waitForTransactionReceipt, readContract } from "wagmi/actions";
import { metaMorphoFactoryAbi } from "../abi/metaMorphoFactoryAbi";
import { Address } from "viem";
import { flowPreviewnet } from "viem/chains";
import { contracts } from "../config/markets";
import { randomBytes } from "crypto";

const Home: NextPage = () => {
  const sepolia = {
    id: 11_155_111,
    name: "Sepolia",
    nativeCurrency: { name: "Sepolia Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: {
      default: {
        http: [
          "https://eth-sepolia.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT",
        ],
      },
    },
    blockExplorers: {
      default: {
        name: "Etherscan",
        url: "https://sepolia.etherscan.io",
        apiUrl: "https://api-sepolia.etherscan.io/api",
      },
    },
    contracts: {
      multicall3: {
        address: "0xca11bde05977b3631167028862be2a173976ca11",
        blockCreated: 751532,
      },
      ensRegistry: { address: "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e" },
      ensUniversalResolver: {
        address: "0xc8Af999e38273D658BE1b921b88A9Ddf005769cC",
        blockCreated: 5_317_080,
      },
    },
    testnet: true,
  } as const satisfies Chain;

  const polygonAmoy = {
    id: 80_002,
    name: "Polygon Amoy",
    nativeCurrency: { name: "MATIC", symbol: "MATIC", decimals: 18 },
    rpcUrls: {
      default: {
        http: ["https://rpc-amoy.polygon.technology"],
      },
    },
    blockExplorers: {
      default: {
        name: "PolygonScan",
        url: "https://polygon-amoy.g.alchemy.com/v2/jXLoZTSjTIhZDB9nNhJsSmvrcMAbdrNT",
        apiUrl: "https://api-amoy.polygonscan.com/api",
      },
    },
    contracts: {
      multicall3: {
        address: "0xca11bde05977b3631167028862be2a173976ca11",
        blockCreated: 3127388,
      },
    },
    testnet: true,
  } as const satisfies Chain;

  const config = getDefaultConfig({
    appName: "My RainbowKit App",
    projectId: "YOUR_PROJECT_ID",
    chains: [sepolia, flowPreviewnet, polygonAmoy],
  });

  const account = useAccount();
  const chainId = useChainId();
  const { writeContractAsync } = useWriteContract();

  const [inputTimeLock, setInputTimeLock] = useState("");
  const [inputAssetAddress, setInputAssetAddress] = useState("");
  const [inputName, setInputName] = useState("");
  const [inputSymbol, setInputSymbol] = useState("");
  const [morphoContractAddress, setMorphoContractAddress] = useState(
    contracts[chainId].morpho as Address
  );
  const [morphoFactoryAddress, setMorphoFactoryAddress] = useState(
    contracts[chainId].metaMorphoFactory as Address
  );

  useEffect(() => {
    if (account && account.isConnected && account.chainId) {
      setMorphoFactoryAddress(
        contracts[account.chainId].metaMorphoFactory as Address
      );
    }
  }, [chainId, account]);

  useAccountEffect({
    onConnect(data) {
      if (!data.isReconnected) {
        setMorphoFactoryAddress(
          contracts[data.chainId].metaMorphoFactory as Address
        );
      }
    },
  });

  function getChain() {
    if (chainId) {
      if (chainId == sepolia.id) {
        return sepolia.id;
      } else if (chainId == flowPreviewnet.id) {
        return flowPreviewnet.id;
      } else if (chainId == polygonAmoy.id) {
        return polygonAmoy.id;
      }
    } else {
      return sepolia.id;
    }
  }

  const handleInputTimeLockChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputTimeLock(event.target.value);
  };
  const handleinputAssetAddressChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputAssetAddress(event.target.value);
  };

  const handleInputNameChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputName(event.target.value);
  };

  const handleInputSymbolChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputSymbol(event.target.value);
  };

  function generateRandomBytes32(): string {
    const buffer = randomBytes(32);
    return buffer.toString("hex");
  }

  const handleCreateVaultClick = async () => {
    const salt = generateRandomBytes32();

    const createMetaMorphoArgs = [
      account.address,
      inputTimeLock,
      inputAssetAddress as Address,
      inputName as String,
      inputSymbol as String,
      "0x" + salt,
    ];
    const txHash = await writeContractAsync({
      address: morphoFactoryAddress,
      abi: metaMorphoFactoryAbi,
      functionName: "createMetaMorpho",
      args: createMetaMorphoArgs,
    });
    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });

    // const response = await fetch("/api/updateMarkets", {
    //   method: "POST",
    //   headers: {
    //     "Content-Type": "application/json",
    //   },
    //   body: JSON.stringify({
    //     name: "markets",
    //     value: createMarketArgs,
    //     chainId: getChain(),
    //   }),
    // });

    // localStorage.setItem("markets", JSON.stringify([createMarketArgs]));

    // const result = await response.json();
    // console.log(result.message);
  };

  return (
    <div className={styles.container}>
      <Head>
        <title>Morpho Demo</title>
      </Head>

      <main className={styles.main}>
        <Box
          display="flex"
          flexDirection="column"
          alignItems="center"
          justifyContent="center"
          marginTop={1}
        >
          <Box sx={{ fontWeight: "bold" }}>{"Create Vault"}</Box>

          <Box
            display="flex"
            alignItems="center"
            justifyContent="center"
            width="100%"
            maxWidth={600}
            marginBottom={2}
          >
            <TextField
              fullWidth
              label={
                account.isConnected
                  ? "Enter time lock from 89400 to 1209600"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputTimeLock}
              onChange={handleInputTimeLockChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
          </Box>

          <Box
            display="flex"
            alignItems="center"
            justifyContent="center"
            width="100%"
            maxWidth={600}
            marginBottom={2}
          >
            <TextField
              fullWidth
              label={
                account.isConnected
                  ? "Enter asset address"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputAssetAddress}
              onChange={handleinputAssetAddressChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
          </Box>

          <Box
            display="flex"
            alignItems="center"
            justifyContent="center"
            width="100%"
            maxWidth={600}
            marginBottom={2}
          >
            <TextField
              fullWidth
              label={
                account.isConnected
                  ? "Enter name of vault token"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputName}
              onChange={handleInputNameChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
          </Box>

          <Box
            display="flex"
            alignItems="center"
            justifyContent="center"
            width="100%"
            maxWidth={600}
            marginBottom={2}
          >
            <TextField
              fullWidth
              label={
                account.isConnected
                  ? "Enter symbol of vault token"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputSymbol}
              onChange={handleInputSymbolChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
          </Box>

          <Box
            display="flex"
            alignItems="center"
            justifyContent="center"
            width="100%"
            maxWidth={600}
            marginBottom={2}
          >
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleCreateVaultClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              CREATE VAULT
            </Button>
          </Box>
        </Box>
      </main>

      <footer className={styles.footer}></footer>
    </div>
  );
};

export default Home;
