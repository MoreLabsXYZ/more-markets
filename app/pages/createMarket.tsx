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
import { morphoAbi } from "../abi/morphoAbi";
import { Address } from "viem";
import { flowPreviewnet, polygonAmoy } from "viem/chains";
import { contracts } from "../config/markets";

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

  const config = getDefaultConfig({
    appName: "My RainbowKit App",
    projectId: "YOUR_PROJECT_ID",
    chains: [sepolia, flowPreviewnet, polygonAmoy],
  });

  const account = useAccount();
  const chainId = useChainId();
  const { writeContractAsync } = useWriteContract();

  const [inputLoanTokenAddress, setInputLoanTokenAddress] = useState("");
  const [inputCollateralTokenAddress, setInputCollateralTokenAddress] =
    useState("");
  const [inputOracleContract, setInputOracleContract] = useState("");
  const [inputIrmContract, setInputIrmContract] = useState("");
  const [inputLltv, setInputLltv] = useState("");
  const [morphoContractAddress, setMorphoContractAddress] = useState(
    contracts[chainId].morpho as Address
  );

  useEffect(() => {
    if (account && account.isConnected && account.chainId) {
      setMorphoContractAddress(contracts[account.chainId].morpho as Address);
    }
  }, [chainId]);

  useAccountEffect({
    onConnect(data) {
      if (!data.isReconnected) {
        setMorphoContractAddress(contracts[data.chainId].morpho as Address);
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

  const handleInputLoanTokenChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputLoanTokenAddress(event.target.value);
  };
  const handleinputCollateralTokenChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputCollateralTokenAddress(event.target.value);
  };

  const handleInputOracleContractChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputOracleContract(event.target.value);
  };

  const handleInputIrmContractChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputIrmContract(event.target.value);
  };

  const handleInputLltvChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputLltv(event.target.value);
  };

  const handleCreateMarketClick = async () => {
    const createMarketArgs = {
      loanToken: inputLoanTokenAddress as Address,
      collateralToken: inputCollateralTokenAddress as Address,
      oracle: inputOracleContract as Address,
      irm: inputIrmContract as Address,
      lltv: inputLltv,
    };
    const txHash = await writeContractAsync({
      address: morphoContractAddress,
      abi: morphoAbi,
      functionName: "createMarket",
      args: [createMarketArgs],
    });
    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
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
          <Box sx={{ fontWeight: "bold" }}>{"Create Market"}</Box>

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
                  ? "Enter loan token address"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputLoanTokenAddress}
              onChange={handleInputLoanTokenChange}
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
                  ? "Enter collateral token address"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputCollateralTokenAddress}
              onChange={handleinputCollateralTokenChange}
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
                  ? "Enter oracle contract address"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputOracleContract}
              onChange={handleInputOracleContractChange}
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
                  ? "Enter irm contract address"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputIrmContract}
              onChange={handleInputIrmContractChange}
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
                  ? "Enter lltv value"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputLltv}
              onChange={handleInputLltvChange}
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
              onClick={handleCreateMarketClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              CREATE MARKET
            </Button>
          </Box>
        </Box>
      </main>

      <footer className={styles.footer}></footer>
    </div>
  );
};

export default Home;
