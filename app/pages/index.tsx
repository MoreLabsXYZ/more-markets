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
import { flowPreviewnet, polygonAmoy } from "viem/chains";
import { chainConfig, markets, contracts, Markets } from "../config/markets";
import { getChainId } from "viem/actions";
import Link from "next/link";

const Home: NextPage = () => {
  const account = useAccount();
  const [marketsArray, setMarketsArray] = useState(markets);

  useEffect(() => {
    const storedMarkets: Markets = JSON.parse(
      localStorage.getItem("markets") || "[]"
    );
    console.log("storedMarkets: ", storedMarkets);
    setMarketsArray(markets);
  }, []);

  function renderTableRow(): ReactNode[] {
    if (account.isConnected && account.chainId) {
      return marketsArray[account.chainId!].map(
        (market: { name: string; address: string }, index) => (
          <TableRow
            key={market.address}
            component={Link}
            href={{
              pathname: "/market",
              query: { market: market.address as string },
            }}
            style={{
              cursor: "pointer",
              textDecoration: "none",
              color: "inherit",
            }}
            sx={{ "&:last-child td, &:last-child th": { border: 0 } }}
          >
            <TableCell>{index}</TableCell>
            <TableCell align="right">{market.name}</TableCell>
            <TableCell align="right">{market.address}</TableCell>
          </TableRow>
        )
      );
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
                <TableCell align="right">Name</TableCell>
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
