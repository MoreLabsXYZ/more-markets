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
  // const chain = useNetwork();
  // const config = useConfig();
  const { writeContractAsync } = useWriteContract();

  const [inputSkimRecipient, setInputSupplyAssets] = useState("");
  const [inputSkimTokenAddress, setInputSkimTokenAddress] = useState("");
  const [inputFee, setInputFee] = useState("");
  const [inputTimeLock, setInputTimeLock] = useState("");
  const [inputFeeRecipient, setFeeRecipient] = useState("");
  const [inputSubmitMarketId, setInputSubmitMarketId] = useState("");
  const [inputSubmitCap, setInputSubmitCap] = useState("");
  const [inputAcceptMarketId, setInputAcceptMarketId] = useState("");
  const [inputSubmitMarketRemovalId, setInputSubmitMarketRemovalId] =
    useState("");
  const [inputSupplyQueue, setInputSuplyQueue] = useState("");
  const [inputWithdrawQueue, setInputWithdrawQueue] = useState("");
  const [inputReallocateMarkets, setInputReallocateMarkets] = useState("");
  const [inputReallocateAssets, setInputReallocateAssets] = useState("");
  const [inputRoleAddress, setInputRoleAddress] = useState("");
  const [inputRoleStatus, setInputRoleStatus] = useState("");

  const [vaultParams, setVaultParams] = useState("");
  const searchParams1 = useSearchParams();

  const [metaMorphoFactoryAddress, setmetaMorphoFactoryAddress] = useState(
    contracts[chainId].metaMorphoFactory as Address
  );
  const [metaMorphoContractAddress, setMetaMorphoContractAddress] = useState(
    searchParams1.get("vault")!
  );
  const [morphoContractAddress, setMorphoContractAddress] = useState(
    contracts[chainId].morpho as Address
  );
  const [decimal, setDecimal] = useState(0);
  const [vaultArray, setVaultsArray] = useState([""]);
  const [selectedOption, setSelectedOption] = useState("");

  useAccountEffect({
    onConnect(userData) {
      setMorphoContractAddress(contracts[userData.chainId].morpho as Address);
      setmetaMorphoFactoryAddress(
        contracts[userData.chainId].metaMorphoFactory as Address
      );
      if (!userData.isReconnected) {
        if (vaultArray) {
          setMetaMorphoContractAddress(vaultArray[0]);
        }
      }
    },
  });

  useEffect(() => {
    if (chainId == sepolia.id) {
      getVaults(metaMorphoFactoryAddress);
    }
  }, [metaMorphoFactoryAddress]);

  useEffect(() => {
    if (account && account.isConnected && metaMorphoContractAddress) {
      getPosition();
      getVaultParams();
    }
  }, [metaMorphoContractAddress, searchParams1]);

  useEffect(() => {
    if (account && account.isConnected && account.chainId) {
      setMorphoContractAddress(contracts[account.chainId].morpho as Address);
      setmetaMorphoFactoryAddress(
        contracts[account.chainId].metaMorphoFactory as Address
      );
    }
  }, [chainId, account]);

  // useEffect(() => {
  //   if (marketsArray) {
  //     setCurrentMarket(marketsArray[0]);
  //   } else {
  //     redirect("/");
  //   }
  // }, [marketsArray]);

  useEffect(() => {
    console.log("searchParams1 changed ", searchParams1);
    console.log(
      "metaMorphoContractAddress changed ",
      metaMorphoContractAddress
    );
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
  };

  const getVaults = async (morphoFactoryAddress: Address) => {
    const vaults: any = await readContract(config, {
      address: morphoFactoryAddress,
      abi: metaMorphoFactoryAbi,
      functionName: "arrayOfMorphos",
      chainId: getChain(),
      args: [],
    });
    setVaultsArray(vaults);
  };

  const getVaultParams = async () => {
    const params: any = await readContract(config, {
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "asset",
      chainId: getChain(),
      args: [],
    });
    setVaultParams(params);
    console.log("vault params: ", params);

    const decimal: any = await readContract(config, {
      address: params as Address,
      abi: ERC20MintableBurnableAbi,
      functionName: "decimals",
      chainId: getChain(),
      args: [],
    });
    setDecimal(decimal);
  };

  const handleSkimRecipientChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputSupplyAssets(event.target.value);
  };

  const handleSkimChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setInputSkimTokenAddress(event.target.value);
  };

  const handleInputFeeChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    setInputFee(event.target.value);
  };
  const handleInputTimeLockChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputTimeLock(event.target.value);
  };
  const handleInputFeeRecipientChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setFeeRecipient(event.target.value);
  };

  const handleInputSubmitMarketIdChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputSubmitMarketId(event.target.value);
  };

  const handleInputSubmitCapChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputSubmitCap(event.target.value);
  };

  const handleInputAcceptMarketIdChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputAcceptMarketId(event.target.value);
  };

  const handleInputSubmitMarketRemovalIdChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputSubmitMarketRemovalId(event.target.value);
  };

  const handleInputSupplyQueueChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputSuplyQueue(event.target.value);
  };

  const handleInputWithdrawQueueChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputWithdrawQueue(event.target.value);
  };

  const handleInputReallocateMarketsChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputReallocateMarkets(event.target.value);
  };

  const handleInputReallocateAssetsChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputReallocateAssets(event.target.value);
  };

  const handleRoleChange = (event: SelectChangeEvent) => {
    setSelectedOption(event.target.value);
  };

  const handleRoleAddressChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputRoleAddress(event.target.value);
  };

  const handleRoleStatusChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputRoleStatus(event.target.value);
  };

  const handleSkimRecipientButtonClick = async () => {
    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "setSkimRecipient",
      args: [inputSkimRecipient as Address],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  const handleSkimButtonClick = async () => {
    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "skim",
      args: [inputSkimTokenAddress as Address],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  const handleSetFeeButtonClick = async () => {
    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "setFee",
      args: [formatUnits(BigInt(inputFee), 18)],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  const handleSetFeeRecipientButtonClick = async () => {
    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "setFeeRecipient",
      args: [inputFeeRecipient],
    });
    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  const handleSubmitTimeLockButtonClick = async () => {
    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "submitTimelock",
      args: [inputTimeLock],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  const handleAcceptTimeLockButtonClick = async () => {
    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "acceptTimelock",
      args: [],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  const handleSubmitCapButtonClick = async () => {
    const MarketParams: any = await readContract(config, {
      address: morphoContractAddress as Address,
      abi: morphoAbi,
      functionName: "idToMarketParams",
      chainId: getChain(),
      args: [inputSubmitMarketId],
    });

    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "submitCap",
      args: [MarketParams, parseUnits(inputSubmitCap, decimal)],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  const handleAcceptCapButtonClick = async () => {
    const MarketParams: any = await readContract(config, {
      address: morphoContractAddress as Address,
      abi: morphoAbi,
      functionName: "idToMarketParams",
      chainId: getChain(),
      args: [inputAcceptMarketId],
    });

    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "acceptCap",
      args: [MarketParams],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  const handleSubmitMarketRemovalButtonClick = async () => {
    const MarketParams: any = await readContract(config, {
      address: morphoContractAddress as Address,
      abi: morphoAbi,
      functionName: "idToMarketParams",
      chainId: getChain(),
      args: [inputSubmitMarketRemovalId],
    });

    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "submitMarketRemoval",
      args: [MarketParams],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  const parseArray = (input: string) => {
    try {
      const parsedArray = input.split(",").map((item) => item.trim());

      return parsedArray;
    } catch (error) {
      alert("Error parsing array");
    }
  };

  const handleSetSupplyQueueButtonClick = async () => {
    const supplyQueue = parseArray(inputSupplyQueue);

    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "setSupplyQueue",
      args: [supplyQueue],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  const handleSetWithdrawQueueButtonClick = async () => {
    const withdrawQueue = parseArray(inputSupplyQueue);

    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "updateWithdrawQueue",
      args: [withdrawQueue],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  const handleReallocateButtonClick = async () => {
    const markets: string[] = parseArray(inputReallocateMarkets)!;
    const assets: string[] = parseArray(inputReallocateAssets)!;

    const MarketsAllocation = [{}];

    for (let i = 0; i < markets.length; i++) {
      MarketsAllocation.push({
        marketParams: markets[i],
        assets: parseUnits(assets[i], decimal),
      });
    }

    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "reallocate",
      args: [MarketsAllocation],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  const handleSetRoleButtonClick = async () => {
    if (selectedOption == "Curator") {
      const txHash = await writeContractAsync({
        address: metaMorphoContractAddress as Address,
        abi: MetaMorphoAbi,
        functionName: "setCurator",
        args: [inputRoleAddress],
      });

      await waitForTransactionReceipt(config, {
        chainId: getChain(),
        hash: txHash,
      });
    } else if (selectedOption == "Guardian") {
      const txHash = await writeContractAsync({
        address: metaMorphoContractAddress as Address,
        abi: MetaMorphoAbi,
        functionName: "submitGuardian",
        args: [inputRoleAddress],
      });

      await waitForTransactionReceipt(config, {
        chainId: getChain(),
        hash: txHash,
      });
    } else if (selectedOption == "Allocator") {
      let status = false;
      if (inputRoleStatus == "true") {
        status = true;
      }
      const txHash = await writeContractAsync({
        address: metaMorphoContractAddress as Address,
        abi: MetaMorphoAbi,
        functionName: "setIsAllocator",
        args: [inputRoleAddress, status],
      });

      await waitForTransactionReceipt(config, {
        chainId: getChain(),
        hash: txHash,
      });
    }
  };

  const handleAcceptGuardianButtonClick = async () => {
    const txHash = await writeContractAsync({
      address: metaMorphoContractAddress as Address,
      abi: MetaMorphoAbi,
      functionName: "acceptGuardian",
      args: [],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
  };

  function renderInputFieldsForRoles(): ReactNode {
    if (account.isConnected && account.chainId) {
      if (selectedOption == "Curator" || selectedOption == "Guardian") {
        return (
          <TextField
            fullWidth
            label={
              account.isConnected
                ? `Enter address to set ${selectedOption.toLowerCase()} role`
                : "Connect wallet first"
            }
            variant="outlined"
            color="secondary"
            value={inputRoleAddress}
            onChange={handleRoleAddressChange}
            margin="normal"
            style={{ width: "300px" }}
            disabled={account.isDisconnected}
            InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
          />
        );
      } else if (selectedOption == "Allocator") {
        return (
          <Box maxWidth={300} marginBottom={2}>
            <TextField
              fullWidth
              label={
                account.isConnected
                  ? `Enter address to set ${selectedOption.toLowerCase()} role`
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputRoleAddress}
              onChange={handleRoleAddressChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
            <TextField
              fullWidth
              label={
                account.isConnected
                  ? `Enter "true" or "false" to set or remove role`
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputRoleStatus}
              onChange={handleRoleStatusChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
          </Box>
        );
      }
      return [];
    }
  }

  function renderButtonForSetRoles(): ReactNode {
    if (account.isConnected && account.chainId) {
      if (selectedOption) {
        return (
          <Button
            variant="outlined"
            color="secondary"
            onClick={handleSetRoleButtonClick}
            style={{
              height: "54px",
              width: "200px",
              marginLeft: "10px",
              marginTop: "7px",
            }}
            sx={{ borderRadius: 3, boxShadow: 1 }}
            disabled={account.isDisconnected}
          >
            SET ROLE
          </Button>
        );
      }
      return [];
    }
  }

  function renderButtonForAcceptGuardian(): ReactNode {
    if (account.isConnected && account.chainId) {
      if (selectedOption == "Guardian") {
        return (
          <Box
            display="flex"
            alignItems="center"
            justifyContent="center"
            width="100%"
            maxWidth={600}
            marginBottom={2}
          >
            <Tooltip title="Have to be accepted if Guardian != address(0)">
              <span>
                <Button
                  variant="outlined"
                  color="secondary"
                  onClick={handleAcceptGuardianButtonClick}
                  style={{
                    height: "54px",
                    width: "200px",
                    marginLeft: "10px",
                    marginTop: "7px",
                  }}
                  sx={{ borderRadius: 3, boxShadow: 1 }}
                  disabled={account.isDisconnected}
                >
                  ACCEPT GUARDIAN
                </Button>
              </span>
            </Tooltip>
          </Box>
        );
      }
      return [];
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
        ></Box>
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
              ? `Vault asset: ${vaultParams}`
              : "Vault params loading..."}
          </Typography>

          <Box
            sx={{ fontWeight: "bold" }}
            style={{ marginTop: "24px" }}
            marginBottom={2}
          >
            {"Role manager functionality:"}
          </Box>

          <Box
            display="flex"
            alignItems="center"
            justifyContent="center"
            width="100%"
            maxWidth={600}
            marginBottom={2}
          >
            <FormControl variant="outlined" fullWidth>
              <InputLabel id="simple-select-label">
                Select role to set
              </InputLabel>
              <Select
                labelId="Select role to set"
                id="select"
                value={selectedOption}
                onChange={handleRoleChange}
                label="Select role to set"
              >
                <MenuItem value="">
                  <em>None</em>
                </MenuItem>
                <MenuItem value="Curator">Curator</MenuItem>
                <MenuItem value="Guardian">Guardian</MenuItem>
                <MenuItem value="Allocator">Allocator</MenuItem>
              </Select>
            </FormControl>
          </Box>

          <Box
            display="flex"
            alignItems="center"
            justifyContent="center"
            width="100%"
            maxWidth={600}
            marginBottom={2}
          >
            {renderInputFieldsForRoles()}
            {renderButtonForSetRoles()}
          </Box>

          {renderButtonForAcceptGuardian()}

          <Box sx={{ fontWeight: "bold" }} style={{ marginTop: "24px" }}>
            {"Vault manager functionality:"}
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
                  ? "Enter skim recipient address"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputSkimRecipient}
              onChange={handleSkimRecipientChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleSkimRecipientButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SET SKIM RECIPIENT
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
                  ? "Enter token address to skim"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputSkimTokenAddress}
              onChange={handleSkimChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleSkimButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              PREFORM SKIM
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
                  ? "Enter new fee value in %"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputFee}
              onChange={handleInputFeeChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleSetFeeButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SET FEE
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
                  ? "Enter new fee recipient address"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputFeeRecipient}
              onChange={handleInputFeeRecipientChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleSetFeeRecipientButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SET FEE RECIPIENT
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
                  ? "Enter new timelock value"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputTimeLock}
              onChange={handleInputTimeLockChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleSubmitTimeLockButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SUBMIT TIMELOCK
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
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleAcceptTimeLockButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              ACCEPT TIMELOCK
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
            <Box maxWidth={300} marginBottom={2}>
              <TextField
                fullWidth
                label={
                  account.isConnected
                    ? "Enter market id"
                    : "Connect wallet first"
                }
                variant="outlined"
                color="secondary"
                value={inputSubmitMarketId}
                onChange={handleInputSubmitMarketIdChange}
                margin="normal"
                style={{ width: "300px" }}
                InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
                disabled={account.isDisconnected}
              />
              <TextField
                fullWidth
                label={
                  account.isConnected ? "Enter cap" : "Connect wallet first"
                }
                variant="outlined"
                color="secondary"
                value={inputSubmitCap}
                onChange={handleInputSubmitCapChange}
                margin="normal"
                style={{ width: "300px" }}
                InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
                disabled={account.isDisconnected}
              />
            </Box>
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleSubmitCapButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SUBMIT CAP
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
                account.isConnected ? "Enter market id" : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputAcceptMarketId}
              onChange={handleInputAcceptMarketIdChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleAcceptCapButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              ACCEPT CAP
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
                account.isConnected ? "Enter market id" : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputSubmitMarketRemovalId}
              onChange={handleInputSubmitMarketRemovalIdChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleSubmitMarketRemovalButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SUBMIT MARKET REMOVAL
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
                  ? "Enter list of market ids separated by comma"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputSupplyQueue}
              onChange={handleInputSupplyQueueChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleSetSupplyQueueButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SET SUPPLY QUEUE
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
                  ? "Enter list indexes separated by comma"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputWithdrawQueue}
              onChange={handleInputWithdrawQueueChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleSetWithdrawQueueButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              UPDATE WITHDRAW QUEUE
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
            <Box maxWidth={300} marginBottom={2}>
              <TextField
                fullWidth
                label={
                  account.isConnected
                    ? "Enter market ids separated by comma"
                    : "Connect wallet first"
                }
                variant="outlined"
                color="secondary"
                value={inputReallocateMarkets}
                onChange={handleInputReallocateMarketsChange}
                margin="normal"
                style={{ width: "300px" }}
                InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
                disabled={account.isDisconnected}
              />
              <TextField
                fullWidth
                label={
                  account.isConnected
                    ? "Enter assets values separated by comma"
                    : "Connect wallet first"
                }
                variant="outlined"
                color="secondary"
                value={inputReallocateAssets}
                onChange={handleInputReallocateAssetsChange}
                margin="normal"
                style={{ width: "300px" }}
                InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
                disabled={account.isDisconnected}
              />
            </Box>
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleReallocateButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              REALLOCATE
            </Button>
          </Box>
        </Box>
      </main>

      <footer className={styles.footer}></footer>
    </div>
  );
};

export default Home;
