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
import { useSearchParams } from "next/navigation";

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

  const [inputLoanToken, setInputLoanToken] = useState("");
  const [inputCollateralToken, setInputCollateralToken] = useState("");
  const [inputSupplyAssets, setInputSupplyAssets] = useState("");
  const [inputWithdrawAssets, setInputWithdrawAssets] = useState("");
  const [inputSupplyCollateralAssets, setInputSupplyCollateralAssets] =
    useState("");
  const [inputWithdrawCollateralAssets, setInputWithdrawCollateralAssets] =
    useState("");
  const [inputBorrowAssets, setInputBorrowAssets] = useState("");
  const [inputRepayAssets, setInputRepayAssets] = useState("");
  const [position, setPosition] = useState();
  const [tokens, setTokens] = useState();
  // const [currentMarket, setCurrentMarket] = useState(markets[account.chainId!][0]);
  const searchParams1 = useSearchParams();
  console.log("search params1: ", searchParams1.get("market"));
  const [currentMarket, setCurrentMarket] = useState(
    searchParams1.get("market")!
  );
  const [morphoContractAddress, setMorphoContractAddress] = useState(
    contracts[chainId].morpho as Address
  );
  const [decimal, setDecimal] = useState(0);

  useEffect(() => {
    console.log("market changed", currentMarket);
    if (account && account.isConnected && currentMarket) {
      getPosition();
      getMarketParams();
    }
    if (currentMarket == markets[sepolia.id][3].address) {
      setDecimal(18);
    } else {
      setDecimal(0);
    }
  }, [currentMarket, searchParams1]);

  useEffect(() => {
    console.log("chain changed", chainId);
    if (account && account.isConnected && account.chainId) {
      setMorphoContractAddress(contracts[account.chainId].morpho as Address);
      setCurrentMarket(markets[account.chainId][0].address);
    }
  }, [chainId]);

  useEffect(() => {
    console.log("chain changed", chainId);
    if (account && account.isConnected && account.chainId) {
      setCurrentMarket(searchParams1.get("market")!);
    }
  }, [searchParams1]);

  useAccountEffect({
    onConnect(data) {
      console.log("connected");
      setMorphoContractAddress(contracts[data.chainId].morpho as Address);
      setCurrentMarket(markets[data.chainId][0].address);
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

  const getPosition = async () => {
    console.log("current market: ", currentMarket);
    console.log("account: ", account.address as Hex);
    console.log("chain: ", getChain());
    console.log("config: ", config);
    const position: any = await readContract(config, {
      address: morphoContractAddress,
      abi: morphoAbi,
      functionName: "position",
      chainId: getChain(),
      args: [currentMarket as Address, account.address as Hex],
    });
    setPosition(position);
  };

  const getMarketParams = async () => {
    const params: any = await readContract(config, {
      address: morphoContractAddress,
      abi: morphoAbi,
      functionName: "idToMarketParams",
      chainId: getChain(),
      args: [currentMarket as Address],
    });
    setTokens(params);
  };

  const handleInputLoanTokenChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputLoanToken(event.target.value);
  };
  const handleInputCollateralTokenChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputCollateralToken(event.target.value);
  };
  const handleInputSupplyAssetsChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputSupplyAssets(event.target.value);
  };

  const handleInputWithdrawAssetsChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputWithdrawAssets(event.target.value);
  };
  const handleInputSupplyCollateralAssetsChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputSupplyCollateralAssets(event.target.value);
  };
  const handleInputWithdrawCollateralAssetsChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputWithdrawCollateralAssets(event.target.value);
  };
  const handleInputBorrowAssetsChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputBorrowAssets(event.target.value);
  };
  const handleInputRepayAssetsChange = (
    event: React.ChangeEvent<HTMLInputElement>
  ) => {
    setInputRepayAssets(event.target.value);
  };
  const handleMarketChange = async (event: SelectChangeEvent) => {
    setCurrentMarket(event.target.value);
  };

  const handleLoanTokenButtonClick = async () => {
    if (currentMarket != markets[sepolia.id][3].address) {
      const txSetBalanceHash = await writeContractAsync({
        address: chainConfig[account.chainId!][currentMarket]
          .loanToken as Address,
        abi: ERC20MockAbi,
        functionName: "setBalance",
        args: [account.address, BigInt(inputLoanToken)],
      });
      await waitForTransactionReceipt(config, {
        chainId: getChain(),
        hash: txSetBalanceHash,
      });
    } else {
      const txMintHash = await writeContractAsync({
        address: chainConfig[account.chainId!][currentMarket]
          .loanToken as Address,
        abi: ERC20MintableBurnableAbi,
        functionName: "mint",
        args: [account.address, parseUnits(inputLoanToken, 18)],
      });
      await waitForTransactionReceipt(config, {
        chainId: getChain(),
        hash: txMintHash,
      });
    }
  };

  const handleCollateralTokenButtonClick = async () => {
    if (currentMarket != markets[sepolia.id][3].address) {
      const txSetBalanceHash = await writeContractAsync({
        address: chainConfig[account.chainId!][currentMarket]
          .collateralToken as Address,
        abi: ERC20MockAbi,
        functionName: "setBalance",
        args: [account.address, BigInt(inputCollateralToken)],
      });
      await waitForTransactionReceipt(config, {
        chainId: getChain(),
        hash: txSetBalanceHash,
      });
    } else {
      const txDepositHash = await writeContractAsync({
        address: chainConfig[account.chainId!][currentMarket]
          .collateralToken as Address,
        abi: WETH9Abi,
        functionName: "deposit",
        args: [],
        value: parseEther(inputCollateralToken),
      });
      await waitForTransactionReceipt(config, {
        chainId: getChain(),
        hash: txDepositHash,
      });
    }
  };

  const handleSupplyButtonClick = async () => {
    const txApproveHash = await writeContractAsync({
      address: chainConfig[account.chainId!][currentMarket]
        .loanToken as Address,
      abi: erc20Abi,
      functionName: "approve",
      args: [
        morphoContractAddress,
        parseUnits(inputSupplyAssets, decimal) + BigInt(1),
      ],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txApproveHash,
    });

    const txHash = await writeContractAsync({
      address: morphoContractAddress,
      abi: morphoAbi,
      functionName: "supply",
      args: [
        {
          loanToken: chainConfig[account.chainId!][currentMarket]
            .loanToken as Address,
          collateralToken: chainConfig[account.chainId!][currentMarket]
            .collateralToken as Address,
          oracle: chainConfig[account.chainId!][currentMarket]
            .oracle as Address,
          irm: chainConfig[account.chainId!][currentMarket].irm as Address,
          lltv: chainConfig[account.chainId!][currentMarket].lltv,
        },
        parseUnits(inputSupplyAssets, decimal),
        BigInt(0),
        account.address,
        "0x",
      ],
    });

    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
    getPosition();
  };

  const handleWithdrawButtonClick = async () => {
    const txHash = await writeContractAsync({
      address: morphoContractAddress,
      abi: morphoAbi,
      functionName: "withdraw",
      args: [
        {
          loanToken: chainConfig[account.chainId!][currentMarket]
            .loanToken as Address,
          collateralToken: chainConfig[account.chainId!][currentMarket]
            .collateralToken as Address,
          oracle: chainConfig[account.chainId!][currentMarket]
            .oracle as Address,
          irm: chainConfig[account.chainId!][currentMarket].irm as Address,
          lltv: chainConfig[account.chainId!][currentMarket].lltv,
        },
        parseUnits(inputWithdrawAssets, decimal),
        BigInt(0),
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
  const handleSupplyCollateralButtonClick = async () => {
    const txApproveHash = await writeContractAsync({
      address: chainConfig[account.chainId!][currentMarket]
        .collateralToken as Address,
      abi: erc20Abi,
      functionName: "approve",
      args: [
        morphoContractAddress,
        parseUnits(inputSupplyCollateralAssets, decimal) + BigInt(1),
      ],
    });
    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txApproveHash,
    });

    const txHash = await writeContractAsync({
      address: morphoContractAddress,
      abi: morphoAbi,
      functionName: "supplyCollateral",
      args: [
        {
          loanToken: chainConfig[account.chainId!][currentMarket]
            .loanToken as Address,
          collateralToken: chainConfig[account.chainId!][currentMarket]
            .collateralToken as Address,
          oracle: chainConfig[account.chainId!][currentMarket]
            .oracle as Address,
          irm: chainConfig[account.chainId!][currentMarket].irm as Address,
          lltv: chainConfig[account.chainId!][currentMarket].lltv,
        },
        parseUnits(inputSupplyCollateralAssets, decimal),
        account.address,
        "0x",
      ],
    });
    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
    getPosition();
  };
  const handleWithdrawCollateralButtonClick = async () => {
    const txHash = await writeContractAsync({
      address: morphoContractAddress,
      abi: morphoAbi,
      functionName: "withdrawCollateral",
      args: [
        {
          loanToken: chainConfig[account.chainId!][currentMarket]
            .loanToken as Address,
          collateralToken: chainConfig[account.chainId!][currentMarket]
            .collateralToken as Address,
          oracle: chainConfig[account.chainId!][currentMarket]
            .oracle as Address,
          irm: chainConfig[account.chainId!][currentMarket].irm as Address,
          lltv: chainConfig[account.chainId!][currentMarket].lltv,
        },
        parseUnits(inputWithdrawCollateralAssets, decimal),
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
  const handleBorrowButtonClick = async () => {
    const txHash = await writeContractAsync({
      address: morphoContractAddress,
      abi: morphoAbi,
      functionName: "borrow",
      args: [
        {
          loanToken: chainConfig[account.chainId!][currentMarket]
            .loanToken as Address,
          collateralToken: chainConfig[account.chainId!][currentMarket]
            .collateralToken as Address,
          oracle: chainConfig[account.chainId!][currentMarket]
            .oracle as Address,
          irm: chainConfig[account.chainId!][currentMarket].irm as Address,
          lltv: chainConfig[account.chainId!][currentMarket].lltv,
        },
        parseUnits(inputBorrowAssets, decimal),
        BigInt(0),
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
  const handleRepayButtonClick = async () => {
    const txApproveHash = await writeContractAsync({
      address: chainConfig[account.chainId!][currentMarket]
        .loanToken as Address,
      abi: erc20Abi,
      functionName: "approve",
      args: [
        morphoContractAddress,
        parseUnits(inputRepayAssets, decimal) + BigInt(1),
      ],
    });
    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txApproveHash,
    });

    const txHash = await writeContractAsync({
      address: morphoContractAddress,
      abi: morphoAbi,
      functionName: "repay",
      args: [
        {
          loanToken: chainConfig[account.chainId!][currentMarket]
            .loanToken as Address,
          collateralToken: chainConfig[account.chainId!][currentMarket]
            .collateralToken as Address,
          oracle: chainConfig[account.chainId!][currentMarket]
            .oracle as Address,
          irm: chainConfig[account.chainId!][currentMarket].irm as Address,
          lltv: chainConfig[account.chainId!][currentMarket].lltv,
        },
        parseUnits(inputRepayAssets, decimal),
        BigInt(0),
        account.address,
        "0x",
      ],
    });
    await waitForTransactionReceipt(config, {
      chainId: getChain(),
      hash: txHash,
    });
    getPosition();
  };

  function renderRow(): ReactNode[] {
    if (account.isConnected && account.chainId) {
      return markets[account.chainId!].map(
        (market: { name: string; address: string }) => (
          <MenuItem key={market.address} value={market.address}>
            market {market.address}
          </MenuItem>
        )
      );
    }
    return [];
  }

  function faucetFunctionality() {
    if (currentMarket != markets[sepolia.id][3].address) {
      return (
        <div>
          <Box sx={{ fontWeight: "bold" }} style={{ marginTop: "24px" }}>
            {"Faucet functionality:"}
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
                  ? "Loan token number to set"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputLoanToken}
              onChange={handleInputLoanTokenChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleLoanTokenButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SET LOAN TOKENS
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
                  ? "Collateral token number to set"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputCollateralToken}
              onChange={handleInputCollateralTokenChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleCollateralTokenButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SET COLLATERAL TOKENS
            </Button>
          </Box>
        </div>
      );
    } else {
      return (
        <div>
          <Box sx={{ fontWeight: "bold" }} style={{ marginTop: "24px" }}>
            {"Faucet functionality:"}
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
                  ? "Loan token number to mint"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputLoanToken}
              onChange={handleInputLoanTokenChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleLoanTokenButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              MINT LOAN TOKENS
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
                  ? "Number of ETH to wrap"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputCollateralToken}
              onChange={handleInputCollateralTokenChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleCollateralTokenButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              WRAP ETH
            </Button>
          </Box>
        </div>
      );
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
          flexDirection="column"
          alignItems="center"
          justifyContent="center"
          marginTop={1}
        >
          {/* <FormControl fullWidth>
            <InputLabel id="demo-simple-select-label">Market</InputLabel>
            <Select
              disabled={account.isDisconnected}
              name="example"
              labelId="demo-simple-select-label"
              id="demo-simple-select"
              value={currentMarket}
              label="market"
              onChange={handleMarketChange}
            >
              {renderRow()}
            </Select>
          </FormControl> */}
          <Box sx={{ fontWeight: "bold" }}>{"Market id: " + currentMarket}</Box>

          <Box sx={{ fontWeight: "bold" }} style={{ marginTop: "24px" }}>
            {"Market params:"}
          </Box>
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {tokens
              ? `Market loan token: ${tokens[0]}`
              : "Market params loading..."}
          </Typography>
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {tokens
              ? `Market collateral token: ${tokens[1]}`
              : "Market params loading..."}
          </Typography>
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {tokens
              ? `Market oracle: ${tokens[2]}`
              : "Market params loading..."}
          </Typography>
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {tokens ? `Market irm: ${tokens[3]}` : "Market params loading..."}
          </Typography>
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {tokens ? `Market lltv: ${tokens[4]}` : "Market params loading..."}
          </Typography>

          {/* 
          <Box sx={{ fontWeight: "bold" }} style={{ marginTop: "24px" }}>
            {"Faucet functionality:"}
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
                  ? "Loan token number to set"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputLoanToken}
              onChange={handleInputLoanTokenChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleLoanTokenButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SET LOAN TOKENS
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
                  ? "Collateral token number to set"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputCollateralToken}
              onChange={handleInputCollateralTokenChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleCollateralTokenButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SET COLLATERAL TOKENS
            </Button>
          </Box> */}
          {faucetFunctionality()}

          <Box sx={{ fontWeight: "bold" }} style={{ marginTop: "24px" }}>
            {"Morpho functionality:"}
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
                  ? "Enter assets to supply"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputSupplyAssets}
              onChange={handleInputSupplyAssetsChange}
              margin="normal"
              style={{ width: "300px" }}
              disabled={account.isDisconnected}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleSupplyButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SUPPLY
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
                  ? "Enter assets to supply collateral"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputSupplyCollateralAssets}
              onChange={handleInputSupplyCollateralAssetsChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleSupplyCollateralButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              SUPPLY COLLATERAL
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
                  ? "Enter assets to withdraw collateral"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputWithdrawCollateralAssets}
              onChange={handleInputWithdrawCollateralAssetsChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleWithdrawCollateralButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              WITHDRAW COLLATERAL
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
                  ? "Enter assets to borrow"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputBorrowAssets}
              onChange={handleInputBorrowAssetsChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleBorrowButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              BORROW
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
                  ? "Enter assets to repay"
                  : "Connect wallet first"
              }
              variant="outlined"
              color="secondary"
              value={inputRepayAssets}
              onChange={handleInputRepayAssetsChange}
              margin="normal"
              style={{ width: "300px" }}
              InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
              disabled={account.isDisconnected}
            />
            <Button
              variant="outlined"
              color="secondary"
              onClick={handleRepayButtonClick}
              style={{
                height: "54px",
                width: "200px",
                marginLeft: "10px",
                marginTop: "7px",
              }}
              sx={{ borderRadius: 3, boxShadow: 1 }}
              disabled={account.isDisconnected}
            >
              REPAY
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
              ? `Position in supply shares: ${formatUnits(
                  position[0],
                  6 + decimal
                )}`
              : "Supply position loading..."}
          </Typography>
          <Typography
            fontSize={"13px"}
            variant="overline"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {position
              ? `Position in borrow shares: ${formatUnits(
                  position[1],
                  6 + decimal
                )}`
              : "Borrow shares position loading..."}
          </Typography>
          <Typography
            fontSize={"13px"}
            variant="overline"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {position
              ? `Position in collateral: ${formatUnits(position[2], decimal)}`
              : "Collateral position loading..."}
          </Typography>
        </Box>
        {/* {error && (
        <div>Error: {(error as BaseError).shortMessage || error.message}</div>
      )} */}
      </main>

      <footer className={styles.footer}></footer>
    </div>
  );
};

export default Home;
