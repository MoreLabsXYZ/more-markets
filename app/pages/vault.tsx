import { ConnectButton, getDefaultConfig, Chain } from "@rainbow-me/rainbowkit";
import type { NextPage } from "next";
import Head from "next/head";
import { useState, useEffect, ReactNode } from "react";
import {
  FormControl,
  Grid,
  InputLabel,
  MenuItem,
  Select,
  SelectChangeEvent,
  Tooltip,
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
// import { morphoAbi } from "../abi/morphoAbi";
import { metaMorphoFactoryAbi } from "../abi/metaMorphoFactoryAbi";
import { MetaMorphoAbi } from "../abi/MetaMorphoAbi";
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
import { flowPreviewnet } from "viem/chains";
import { markets, contracts } from "../config/markets";
import { mockTokens, wrapped, ERC20Mintable } from "../config/tokens";
import { getChainId } from "viem/actions";
import { redirect, useSearchParams } from "next/navigation";
import { ApolloError, gql, useQuery } from "@apollo/client";
import { ApolloClient, InMemoryCache } from "@apollo/client";
import Link from "next/link";
import { useRouter } from "next/router";
import { morphoAbi } from "../abi/morphoAbi";

// const morphoContractAddress = "0xf95D7990e1B914A176f70e2Bb446F2264a66beb8";
// const morphoContractAddress = "0xa138FFFb1C8f8be0896c3caBd0BcA8e4E4A2208d"; sepolia
// const loanTokenAddress = "0x7Aa1Dc017f67f22469BEe3f4be733b2d41EEf485";
// const chainConfig[account.chainId!][currentMarket].collateralToken as Address = "0x5F37B448c318D3FC381A80049e69CBC9185E51C4";

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
  const router = useRouter();
  // const chain = useNetwork();
  // const config = useConfig();
  const { writeContractAsync } = useWriteContract();

  const [inputDepositAssets, setInputSupplyAssets] = useState("");
  const [inputWithdrawAssets, setInputWithdrawAssets] = useState("");
  const [inputMintShares, setInputMintShares] = useState("");
  const [inputRedeemShares, setInputRedeemShares] = useState("");
  const [position, setPosition] = useState({
    shares: 0,
    assets: 0,
  });
  const [vaultParams, setVaultParams] = useState({
    asset: "",
    guardian: "",
    curator: "",
  });
  const searchParams1 = useSearchParams();

  const [metaMorphoFactoryAddress, setmetaMorphoFactoryAddress] = useState(
    contracts[chainId].metaMorphoFactory as Address
  );
  const [metaMorphoContractAddress, setMetaMorphoContractAddress] = useState(
    searchParams1.get("vault")!
  );
  const [decimal, setDecimal] = useState(0);
  const [vaultArray, setVaultsArray] = useState([""]);
  const [vaultOwner, setVaultOwner] = useState("");
  const [vaultAllocations, setVaultAllocations] = useState([]);
  const [totalSupplied, setTotalSupplied] = useState(0);

  useAccountEffect({
    onConnect(userData) {
      setmetaMorphoFactoryAddress(
        contracts[userData.chainId].metaMorphoFactory as Address
      );
    },
  });

  useEffect(() => {
    if (account && account.isConnected && metaMorphoFactoryAddress) {
      getVaults(metaMorphoFactoryAddress);
    }
  }, [metaMorphoFactoryAddress]);

  useEffect(() => {
    if (account && account.isConnected && vaultArray) {
      setMetaMorphoContractAddress(vaultArray[0]);
    }
  }, [vaultArray]);

  // useEffect(() => {
  //   if (account && account.isConnected && metaMorphoContractAddress) {
  //     getVaultOwner();
  //   }
  // }, [metaMorphoContractAddress]);

  useEffect(() => {
    if (account && account.isConnected && metaMorphoContractAddress) {
      getPosition();
      getVaultParams();
      getVaultOwner();
    }
  }, [metaMorphoContractAddress, searchParams1]);

  useEffect(() => {
    if (account && account.isConnected && metaMorphoContractAddress) {
      getVaultAllocations();
    }
  }, [position]);

  useEffect(() => {
    // router.push("/vaultList");
    if (account && account.isConnected && account.chainId) {
      setmetaMorphoFactoryAddress(
        contracts[account.chainId].metaMorphoFactory as Address
      );
    }
  }, [chainId]);

  // useEffect(() => {
  //   if (marketsArray) {
  //     setCurrentMarket(marketsArray[0]);
  //   } else {
  //     redirect("/");
  //   }
  // }, [marketsArray]);

  useEffect(() => {
    if (account && account.isConnected && account.chainId) {
      setMetaMorphoContractAddress(searchParams1.get("vault")!);
    }
  }, [searchParams1]);

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

  const getPosition = async () => {
    const shares: any = await readContract(config, {
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "balanceOf",
      chainId: getChain(),
      args: [account.address],
    });
    const assets: any = await readContract(config, {
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "convertToShares",
      chainId: getChain(),
      args: [shares],
    });

    const newPosition = {
      shares: shares,
      assets: assets,
    };
    setPosition(newPosition);
  };

  const getVaults = async (morphoAddress: Address) => {
    const vaults: any = await readContract(config, {
      address: morphoAddress,
      abi: metaMorphoFactoryAbi,
      functionName: "arrayOfMorphos",
      chainId: getChain(),
      args: [],
    });
    setVaultsArray(vaults);
  };

  const getVaultOwner = async () => {
    const owner: any = await readContract(config, {
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "owner",
      chainId: getChain(),
      args: [],
    });
    setVaultOwner(owner);
  };

  const getVaultParams = async () => {
    const assets: any = await readContract(config, {
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "asset",
      chainId: getChain(),
      args: [],
    });

    const guardian: any = await readContract(config, {
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "guardian",
      chainId: getChain(),
      args: [],
    });

    const curator: any = await readContract(config, {
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "curator",
      chainId: getChain(),
      args: [],
    });

    setVaultParams({ asset: assets, guardian: guardian, curator: curator });

    const decimal: any = await readContract(config, {
      address: assets as Address,
      abi: ERC20MintableBurnableAbi,
      functionName: "decimals",
      chainId: getChain(),
      args: [],
    });
    setDecimal(decimal);
  };

  const getVaultAllocations = async () => {
    const withdrawQueueLength: any = await readContract(config, {
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "withdrawQueueLength",
      chainId: getChain(),
      args: [],
    });

    const allocations: any = [];
    let totalSupply: any = BigInt(0);
    for (let i = 0; i < withdrawQueueLength; i++) {
      const market: any = await readContract(config, {
        address: metaMorphoContractAddress as Address,
        abi: MetaMorphoAbi,
        functionName: "withdrawQueue",
        chainId: getChain(),
        args: [i],
      });
      const position: any = await readContract(config, {
        address: contracts[chainId].morpho as Address,
        abi: morphoAbi,
        functionName: "position",
        chainId: getChain(),
        args: [market, metaMorphoContractAddress as Address],
      });
      const marketInfo: any = await readContract(config, {
        address: contracts[chainId].morpho as Address,
        abi: morphoAbi,
        functionName: "market",
        chainId: getChain(),
        args: [market],
      });
      let assets: BigInt = BigInt(0);
      if (marketInfo.totalSupplyShares != 0) {
        assets = BigInt(
          (position.supplyShares * marketInfo.totalSupplyAssets) /
            marketInfo.totalSupplyShares
        );
      }
      allocations.push({ market: market, assets: assets });
      totalSupply = totalSupply + assets;
    }
    setVaultAllocations(allocations);
    setTotalSupplied(totalSupply);
    console.log("allocations: ", allocations);
    console.log("totalSupply: ", totalSupply);
  };

  const handleInputDepositAssetsChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputSupplyAssets(event.target.value);
  };

  const handleInputWithdrawAssetsChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputWithdrawAssets(event.target.value);
  };
  const handleInputMintSharesChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputMintShares(event.target.value);
  };
  const handleInputRedeemSharesChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputRedeemShares(event.target.value);
  };

  const handleDepositAssetsButtonClick = async () => {
    const txApproveHash = await writeContractAsync({
      address: vaultParams.asset as Address,
      abi: erc20Abi,
      functionName: "approve",
      args: [
        metaMorphoContractAddress as Address,
        parseUnits(inputDepositAssets, decimal),
      ],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txApproveHash,
    });

    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "deposit",
      args: [parseUnits(inputDepositAssets, decimal), account.address],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
    getPosition();
  };

  const handleWithdrawButtonClick = async () => {
    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "withdraw",
      args: [
        parseUnits(inputWithdrawAssets, decimal),
        account.address,
        account.address,
      ],
    });
    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
    getPosition();
  };

  const handleMintSharesButtonClick = async () => {
    const assets: any = await readContract(config, {
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "previewMint",
      chainId: getChain(),
      args: [parseUnits(inputMintShares, decimal)],
    });

    const txApproveHash = await writeContractAsync({
      address: vaultParams.asset as Address,
      abi: erc20Abi,
      functionName: "approve",
      args: [metaMorphoContractAddress as Address, assets],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txApproveHash,
    });

    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "mint",
      args: [parseUnits(inputMintShares, decimal), account.address],
    });
    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
    getPosition();
  };

  const handleRedeemSharesButtonClick = async () => {
    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "redeem",
      args: [
        parseUnits(inputRedeemShares, decimal),
        account.address,
        account.address,
      ],
    });
    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
    getPosition();
  };

  const VaultManageButton = () => {
    const queryParams = new URLSearchParams({
      vault: metaMorphoContractAddress as string,
    }).toString();

    return (
      // <Tooltip title="You have to be the owner of the vault">
      //   <span>
      <Tooltip title="You have to be the owner of the vault">
        <span>
          {vaultOwner != account.address ? (
            <Button
              variant="outlined"
              color="secondary"
              disabled
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
            >
              Manage Vault
            </Button>
          ) : (
            <Link href={`/vaultManager?${queryParams}`} passHref>
              <Button
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
                Manage Vault
              </Button>
            </Link>
          )}
        </span>
      </Tooltip>
    );
  };

  function renderAllocations(): ReactNode {
    if (account.isConnected && account.chainId) {
      if (vaultAllocations.length > 0) {
        return vaultAllocations.map(
          (allocation: { market: string; assets: BigInt }) => (
            <Typography
              key={allocation.market}
              fontSize={"16px"}
              variant="caption"
              noWrap
              sx={{ flex: 1 }}
              style={{ marginTop: "24px" }}
            >
              {totalSupplied != 0
                ? `Assets: ${formatUnits(
                    BigInt(Number(allocation.assets)),
                    decimal
                  )}, Percentage: ${parseFloat(
                    formatUnits(
                      ((BigInt(Number(allocation.assets)) *
                        parseUnits("1", decimal)) /
                        BigInt(totalSupplied)) *
                        BigInt(100),
                      decimal
                    )
                  ).toFixed(2)}%, Market: ${allocation.market}`
                : `No assets were supplied yet.`}
            </Typography>
          )
        );
      } else {
        return (
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            Loading...
          </Typography>
        );
      }
    }
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
          <VaultManageButton />
        </Box>
        <Box
          display="flex"
          flexDirection="column"
          alignItems="center"
          justifyContent="center"
          marginTop={1}
        >
          <Box sx={{ fontWeight: "bold" }}>
            {"Vault address: " + metaMorphoContractAddress}
          </Box>

          <Box sx={{ fontWeight: "bold" }} style={{ marginTop: "24px" }}>
            {"Vault params:"}
          </Box>
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {vaultParams
              ? `Vault asset: ${vaultParams.asset}`
              : "Vault params loading..."}
          </Typography>
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {vaultParams.curator
              ? `Vault Curator: ${vaultParams.curator}`
              : "Vault params loading..."}
          </Typography>
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {vaultParams.guardian
              ? `Vault Guardian: ${vaultParams.guardian}`
              : "Vault params loading..."}
          </Typography>
          <Box sx={{ fontWeight: "bold" }} style={{ marginTop: "24px" }}>
            {"Vault allocations:"}
          </Box>
          {renderAllocations()}

          <Box sx={{ fontWeight: "bold" }} style={{ marginTop: "24px" }}>
            {"Vault functionality:"}
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
                  ? "Enter assets to deposit"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputDepositAssets}
              onChange={handleInputDepositAssetsChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleDepositAssetsButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              DEPOSIT
            </Button>
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
                  ? "Enter assets to withdraw"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputWithdrawAssets}
              onChange={handleInputWithdrawAssetsChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleWithdrawButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              WITHDRAW
            </Button>
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
                  ? "Enter shares amount to be minted"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputMintShares}
              onChange={handleInputMintSharesChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleMintSharesButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              MINT SHARES
            </Button>
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
                  ? "Enter shares to be redeemed"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputRedeemShares}
              onChange={handleInputRedeemSharesChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleRedeemSharesButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              REDEEM SHARES
            </Button>
          </Box>
          <Typography
            fontSize={"13px"}
            variant="overline"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {position
              ? `Position in shares: ${formatUnits(
                  BigInt(position.shares),
                  decimal
                )}`
              : "Shares position loading..."}
          </Typography>
          <Typography
            fontSize={"13px"}
            variant="overline"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {position
              ? `Position in assets: ${formatUnits(
                  BigInt(position.assets),
                  decimal
                )}`
              : "Assets position loading..."}
          </Typography>
        </Box>
      </main>

      <footer className={styles.footer}></footer>
    </div>
  );
};

export default Home;
