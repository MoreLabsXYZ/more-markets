import { ConnectButton, getDefaultConfig, Chain } from "@rainbow-me/rainbowkit";
import type { NextPage } from "next";
import Head from "next/head";
import { useState, useEffect, ReactNode } from "react";
import {
  ButtonBase,
  FormControl,
  Grid,
  InputLabel,
  List,
  ListItem,
  ListItemButton,
  MenuItem,
  Paper,
  Select,
  SelectChangeEvent,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from "@mui/material";
import TextField from "@mui/material/TextField";
import Button from "@mui/material/Button";
import Box from "@mui/material/Box";
import styles from "../styles/Home.module.css";
import {
  useWriteContract,
  useAccount,
  useConfig,
  useAccountEffect,
  createConfig,
  http,
  useChainId,
  WagmiProvider,
} from "wagmi";
import { waitForTransactionReceipt, readContract } from "wagmi/actions";
import { morphoAbi } from "../abi/morphoAbi";
import { ERC20MockAbi } from "../abi/ERC20MockAbi";
import { WETH9Abi } from "../abi/WETH9Abi";
import { ERC20MintableBurnableAbi } from "../abi/ERC20MintableBurnableAbi";
import {
  Address,
  erc20Abi,
  formatUnits,
  Hex,
  parseEther,
  parseUnits,
} from "viem";
import { chainConfig, markets, contracts, Markets } from "../config/markets";
import { getChainId } from "viem/actions";
import Link from "next/link";
import { ApolloError, gql, useQuery } from "@apollo/client";
import { ApolloClient, InMemoryCache } from "@apollo/client";
import { flowPreviewnet } from "wagmi/chains";

const Home: NextPage = () => {
  const account = useAccount();
  const chainId = useChainId();
  const [morphoContractAddress, setMorphoContractAddress] = useState(
    contracts[chainId].morpho as Address
  );
  const [marketsArray, setMarketsArray] = useState([""]);

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

  // useEffect(() => {
  //   if (chainId) {
  //     let subgraphUrl = query_url_sepolia;
  //     switch (chainId) {
  //       case sepolia.id:
  //         subgraphUrl = query_url_sepolia;
  //         break;
  //       case polygonAmoy.id:
  //         subgraphUrl = query_url_amoy;
  //         break;
  //       default:
  //         subgraphUrl = query_url_sepolia;
  //     }

  //     if (subgraphUrl) {
  //       const newClient = new ApolloClient({
  //         uri: subgraphUrl,
  //         cache: new InMemoryCache(),
  //       });
  //       setApolloClient(newClient);
  //     }
  //   }
  // }, [chainId]);

  useEffect(() => {
    if (account && account.isConnected && account.chainId) {
      setMorphoContractAddress(contracts[account.chainId].morpho as Address);
      getMarkets(contracts[account.chainId].morpho as Address);
    }
  }, [chainId, account]);

  const getMarkets = async (morphoAddress: Address) => {
    const markets: any = await readContract(config, {
      address: morphoAddress,
      abi: morphoAbi,
      functionName: "arrayOfMarkets",
      chainId: getChain(),
      args: [],
    });
    setMarketsArray(markets);
  };

  function renderTableRow(): ReactNode {
    // console.log("data: ", data);
    if (account.isConnected && account.chainId) {
      return marketsArray.map((marketId: string, index) => (
        <TableRow
          key={marketId}
          component={Link}
          href={{
            pathname: "/market",
            query: { market: marketId as string },
          }}
          style={{
            cursor: "pointer",
            textDecoration: "none",
            color: "inherit",
          }}
          sx={{ "&:last-child td, &:last-child th": { border: 0 } }}
        >
          <TableCell>{index}</TableCell>
          <TableCell align="right">{marketId}</TableCell>
        </TableRow>
      ));
    }
    return [];
  }

  return (
    <div className={styles.container}>
      <Head>
        <title>Morpho Demo</title>
      </Head>

      <main className={styles.main}>
        <Box
          display="flex"
          alignItems="right"
          justifyContent="right"
          width="100%"
          marginBottom={2}
        >
          <Button
            component={Link}
            href="/createMarket"
            variant="outlined"
            color="secondary"
            disabled={account.isConnected ? false : true}
            style={{
              height: "54px",
              width: "200px",
              marginLeft: "10px",
              marginTop: "7px",
            }}
            sx={{ borderRadius: 3, boxShadow: 1 }}
          >
            CREATE MARKET
          </Button>
        </Box>

        <Box
          display="flex"
          alignItems="left"
          justifyContent="left"
          width="100%"
          marginBottom={2}
        >
          <Typography
            fontSize={"16px"}
            variant="h6"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            My markets:
          </Typography>
        </Box>

        {/* <List>{renderRow()}</List> */}
        <TableContainer component={Paper}>
          <Table sx={{ minWidth: 650 }} aria-label="simple table">
            <TableHead>
              <TableRow>
                <TableCell>Id</TableCell>
                <TableCell align="right">Market Id</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>{renderTableRow()}</TableBody>
          </Table>
        </TableContainer>
      </main>

      <footer className={styles.footer}></footer>
    </div>
  );
};

export default Home;
