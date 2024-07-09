import { getDefaultConfig, Chain } from "@rainbow-me/rainbowkit";
import type { NextPage } from "next";
import Head from "next/head";
import { useState, useEffect, ReactNode } from "react";
import {
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from "@mui/material";
import Button from "@mui/material/Button";
import Box from "@mui/material/Box";
import styles from "../styles/Home.module.css";
import { useAccount, useChainId } from "wagmi";
import { readContract } from "wagmi/actions";
import { metaMorphoFactoryAbi } from "../abi/metaMorphoFactoryAbi";
import { MetaMorphoAbi } from "../abi/MetaMorphoAbi";
import { Address } from "viem";
import { contracts } from "../config/markets";
import Link from "next/link";
import { flowPreviewnet } from "wagmi/chains";

const Home: NextPage = () => {
  const account = useAccount();
  const chainId = useChainId();
  const [morphoFactoryAddress, setMorphoFactoryAddress] = useState(
    contracts[chainId].metaMorphoFactory as Address
  );

  const [vaultsArray, setVaultsArray] = useState([""]);
  //   const [vaultNamesArray, setVaultNamesArray] = useState([""]);

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

  useEffect(() => {
    if (account && account.isConnected && account.chainId) {
      setMorphoFactoryAddress(contracts[account.chainId].morpho as Address);
      getVaults(contracts[account.chainId].metaMorphoFactory as Address);
    }
  }, [chainId, account]);

  const getVaults = async (morphoAddress: Address) => {
    const vaults: any = await readContract(config, {
      address: morphoAddress,
      abi: metaMorphoFactoryAbi,
      functionName: "arrayOfMorphos",
      chainId: getChain(),
      args: [],
    });
    setVaultsArray(vaults);

    // let vaultNames: string[] = [];
    // vaults.map(async (vaultAddress: Address) => {
    //   const vaultName: any = await readContract(config, {
    //     address: vaultAddress,
    //     abi: MetaMorphoAbi,
    //     functionName: "name",
    //     chainId: getChain(),
    //     args: [],
    //   });
    //   console.log("name: ", vaultName);
    //   vaultNames.push(vaultName);
    //   console.log("name: ", vaultNames);
    // });
    // console.log("name after: ", vaultNames);
    // setVaultNamesArray(vaultNames);
  };

  //   const getVaultName = async (vaultAddress: Address) => {
  //     const vaultName: any = await readContract(config, {
  //       address: vaultAddress,
  //       abi: MetaMorphoAbi,
  //       functionName: "name",
  //       chainId: getChain(),
  //       args: [],
  //     });
  //     return vaultName;
  //   };

  function renderTableRow(): ReactNode {
    // console.log("data: ", data);
    if (account.isConnected && account.chainId) {
      return vaultsArray.map((vaultAddress: string, index) => (
        <TableRow
          key={vaultAddress}
          component={Link}
          href={{
            pathname: "/vault",
            query: { vault: vaultAddress as string },
          }}
          style={{
            cursor: "pointer",
            textDecoration: "none",
            color: "inherit",
          }}
          sx={{ "&:last-child td, &:last-child th": { border: 0 } }}
        >
          <TableCell>{index}</TableCell>
          {/* <TableCell>{vaultNamesArray[index]}</TableCell> */}
          <TableCell align="right">{vaultAddress}</TableCell>
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
            href="/createVault"
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
            CREATE VAULT
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
                {/* <TableCell>Name</TableCell> */}
                <TableCell align="right">Vault Address</TableCell>
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
