import { ConnectButton, getDefaultConfig, Chain } from "@rainbow-me/rainbowkit";
import type { NextPage } from "next";
import Head from "next/head";
import { useState, useEffect, ReactNode } from "react";
import {
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
import { chainConfig, markets, contracts } from "../config/markets";
import { getChainId } from "viem/actions";
import Link from "next/link";

// const morphoContractAddress = "0xf95D7990e1B914A176f70e2Bb446F2264a66beb8";
// const morphoContractAddress = "0xa138FFFb1C8f8be0896c3caBd0BcA8e4E4A2208d"; sepolia
// const loanTokenAddress = "0x7Aa1Dc017f67f22469BEe3f4be733b2d41EEf485";
// const chainConfig[account.chainId!][currentMarket].collateralToken as Address = "0x5F37B448c318D3FC381A80049e69CBC9185E51C4";

const Home: NextPage = () => {
  const account = useAccount();

  function renderRow(): ReactNode[] {
    if (account.isConnected && account.chainId) {
      return markets[account.chainId!].map(
        (market: { name: string; address: string }) => (
          <ListItem key={market.address}>
            <ListItemButton>
              <Link
                href={{
                  pathname: "/market",
                  query: {
                    market: market.address as string,
                  },
                }}
              >
                market {market.address}
              </Link>
            </ListItemButton>
          </ListItem>
        )
      );
    }
    return [];
  }

  function renderTableRow(): ReactNode[] {
    if (account.isConnected && account.chainId) {
      return markets[account.chainId!].map(
        (market: { name: string; address: string }, index) => (
          <Link
            key={market.address}
            href={{
              pathname: "/market",
              query: {
                market: market.address as string,
              },
            }}
          >
            <TableRow
              key={index}
              sx={{ "&:last-child td, &:last-child th": { border: 0 } }}
            >
              <TableCell component="th" scope="row">
                {index}
              </TableCell>
              <TableCell align="right">{market.name}</TableCell>
              <TableCell align="right">{market.address}</TableCell>
            </TableRow>
          </Link>
        )
      );
    }
    return [];
  }

  // function createData(
  //   index: number,
  //   name: string,
  //   id: string
  // ) {
  //   return { index, name, id };
  // }

  // const rows = [
  //   createData("Frozen yoghurt", 159, 6.0, 24, 4.0),
  //   createData("Ice cream sandwich", 237, 9.0, 37, 4.3),
  //   createData("Eclair", 262, 16.0, 24, 6.0),
  //   createData("Cupcake", 305, 3.7, 67, 4.3),
  //   createData("Gingerbread", 356, 16.0, 49, 3.9),
  // ];

  return (
    <div className={styles.container}>
      <Head>
        <title>Morpho Demo</title>
      </Head>

      <main className={styles.main}>
        <List>{renderRow()}</List>
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
