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
import { flowPreviewnet } from "viem/chains";
import { markets, contracts } from "../config/markets";
import { mockTokens, wrapped, ERC20Mintable } from "../config/tokens";
import { getChainId } from "viem/actions";
import { redirect, useSearchParams } from "next/navigation";
import { ApolloError, gql, useQuery } from "@apollo/client";
import { ApolloClient, InMemoryCache } from "@apollo/client";

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
  const [position, setPosition] = useState({
    supplyShares: 0,
    borrowShares: 0,
    collateral: 0,
  });
  const [marketParams, setMarketParams] = useState({
    loanToken: "",
    collateralToken: "",
    oracle: "",
    irm: "",
    lltv: 0,
  });
  // const [currentMarket, setCurrentMarket] = useState(markets[account.chainId!][0]);
  const searchParams1 = useSearchParams();
  // console.log("search params1: ", searchParams1.get("market"));
  const [currentMarket, setCurrentMarket] = useState(
    searchParams1.get("market")!
  );
  const [morphoContractAddress, setMorphoContractAddress] = useState(
    contracts[chainId].morpho as Address
  );
  const [decimal, setDecimal] = useState(0);
  const [marketsArray, setMarketsArray] = useState([""]);

  useAccountEffect({
    onConnect(userData) {
      setMorphoContractAddress(contracts[userData.chainId].morpho as Address);
      if (!userData.isReconnected) {
        if (marketsArray) {
          setCurrentMarket(marketsArray[0]);
        }
      }
    },
  });

  useEffect(() => {
    getMarkets(morphoContractAddress);
  }, [morphoContractAddress]);

  useEffect(() => {
    if (account && account.isConnected && currentMarket) {
      console.log("inside ", account.chainId);
      console.log("inside ", morphoContractAddress);
      getPosition();
      getMarketParams();
    }
    if (currentMarket == markets[sepolia.id][3]) {
      setDecimal(18);
    } else {
      setDecimal(0);
    }
  }, [currentMarket, searchParams1]);

  useEffect(() => {
    if (account && account.isConnected && account.chainId) {
      setMorphoContractAddress(contracts[account.chainId].morpho as Address);
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
    console.log("searchParams1 changed ", chainId);
    if (account && account.isConnected && account.chainId) {
      setCurrentMarket(searchParams1.get("market")!);
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
    console.log("current market: ", currentMarket);
    console.log("account: ", account.address as Hex);
    console.log("chain: ", getChain());
    console.log("morpho: ", morphoContractAddress);
    console.log("config: ", config);
    const position: any = await readContract(config, {
      address: morphoContractAddress,
      abi: morphoAbi,
      functionName: "position",
      chainId: getChain(),
      args: [currentMarket as Address, account.address as Hex],
    });
    setPosition(position);
    console.log("postition: ", position);
  };

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

  const getMarketParams = async () => {
    const params: any = await readContract(config, {
      address: morphoContractAddress,
      abi: morphoAbi,
      functionName: "idToMarketParams",
      chainId: getChain(),
      args: [currentMarket as Address],
    });
    setMarketParams(params);
    console.log("market params: ", params);
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
    if (currentMarket != markets[sepolia.id][3]) {
      const txSetBalanceHash = await writeContractAsync({
        address: marketParams?.loanToken as Address,
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
        address: marketParams?.loanToken as Address,
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
    if (currentMarket != markets[sepolia.id][3]) {
      const txSetBalanceHash = await writeContractAsync({
        address: marketParams?.collateralToken as Address,
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
        address: marketParams?.collateralToken as Address,
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
      address: marketParams?.loanToken as Address,
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
          loanToken: marketParams?.loanToken as Address,
          collateralToken: marketParams?.collateralToken as Address,
          oracle: marketParams?.oracle as Address,
          irm: marketParams?.irm as Address,
          lltv: marketParams?.lltv,
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
          loanToken: marketParams?.loanToken as Address,
          collateralToken: marketParams?.collateralToken as Address,
          oracle: marketParams?.oracle as Address,
          irm: marketParams?.irm as Address,
          lltv: marketParams?.lltv,
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
      address: marketParams?.collateralToken as Address,
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
          loanToken: marketParams?.loanToken as Address,
          collateralToken: marketParams?.collateralToken as Address,
          oracle: marketParams?.oracle as Address,
          irm: marketParams?.irm as Address,
          lltv: marketParams?.lltv,
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
          loanToken: marketParams?.loanToken as Address,
          collateralToken: marketParams?.collateralToken as Address,
          oracle: marketParams?.oracle as Address,
          irm: marketParams?.irm as Address,
          lltv: marketParams?.lltv,
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
          loanToken: marketParams?.loanToken as Address,
          collateralToken: marketParams?.collateralToken as Address,
          oracle: marketParams?.oracle as Address,
          irm: marketParams?.irm as Address,
          lltv: marketParams?.lltv,
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
      address: marketParams?.loanToken as Address,
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
          loanToken: marketParams?.loanToken as Address,
          collateralToken: marketParams?.collateralToken as Address,
          oracle: marketParams?.oracle as Address,
          irm: marketParams?.irm as Address,
          lltv: marketParams?.lltv,
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

  // function renderRow(): ReactNode[] {
  //   if (account.isConnected && account.chainId) {
  //     return markets[account.chainId!].map(
  //       (market: { name: string; address: string }) => (
  //         <MenuItem key={market.address} value={market.address}>
  //           market {market.address}
  //         </MenuItem>
  //       )
  //     );
  //   }
  //   return [];
  // }

  function faucetTokens(token: string, type: string) {
    if (mockTokens.includes(token)) {
      return (
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
                ? `${type} token number to set`
                : "Connect wallet first"
            }
            variant="outlined"
            color="secondary"
            value={type == "loan" ? inputLoanToken : inputCollateralToken}
            onChange={
              type == "loan"
                ? handleInputLoanTokenChange
                : handleInputCollateralTokenChange
            }
            margin="normal"
            style={{ width: "300px" }}
            disabled={account.isDisconnected}
            InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
          />
          <Button
            variant="outlined"
            color="secondary"
            onClick={
              type == "loan"
                ? handleLoanTokenButtonClick
                : handleCollateralTokenButtonClick
            }
            style={{
              height: "54px",
              width: "200px",
              marginLeft: "10px",
              marginTop: "7px",
            }}
            sx={{ borderRadius: 3, boxShadow: 1 }}
            disabled={account.isDisconnected}
          >
            SET {type.toUpperCase()} TOKENS
          </Button>
        </Box>
      );
    }
    if (ERC20Mintable.includes(token)) {
      return (
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
                ? `${type} token number to mint`
                : "Connect wallet first"
            }
            variant="outlined"
            color="secondary"
            value={type == "loan" ? inputLoanToken : inputCollateralToken}
            onChange={
              type == "loan"
                ? handleInputLoanTokenChange
                : handleInputCollateralTokenChange
            }
            margin="normal"
            style={{ width: "300px" }}
            disabled={account.isDisconnected}
            InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
          />
          <Button
            variant="outlined"
            color="secondary"
            onClick={
              type == "loan"
                ? handleLoanTokenButtonClick
                : handleCollateralTokenButtonClick
            }
            style={{
              height: "54px",
              width: "200px",
              marginLeft: "10px",
              marginTop: "7px",
            }}
            sx={{ borderRadius: 3, boxShadow: 1 }}
            disabled={account.isDisconnected}
          >
            MINT {type} TOKENS
          </Button>
        </Box>
      );
    }
    if (wrapped.includes(token)) {
      return (
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
                ? "Number of native to wrap"
                : "Connect wallet first"
            }
            variant="outlined"
            color="secondary"
            value={type == "loan" ? inputLoanToken : inputCollateralToken}
            onChange={
              type == "loan"
                ? handleInputLoanTokenChange
                : handleInputCollateralTokenChange
            }
            margin="normal"
            style={{ width: "300px" }}
            disabled={account.isDisconnected}
            InputProps={{ sx: { borderRadius: 3, boxShadow: 1 } }}
          />
          <Button
            variant="outlined"
            color="secondary"
            onClick={
              type == "loan"
                ? handleLoanTokenButtonClick
                : handleCollateralTokenButtonClick
            }
            style={{
              height: "54px",
              width: "200px",
              marginLeft: "10px",
              marginTop: "7px",
            }}
            sx={{ borderRadius: 3, boxShadow: 1 }}
            disabled={account.isDisconnected}
          >
            WRAP ETH AS {type.toUpperCase()} TOKEN
          </Button>
        </Box>
      );
    }
  }
  function faucetFunctionality() {
    let showLoanToken = false;
    let showCollateralToken = false;
    if (
      marketParams?.loanToken &&
      (mockTokens.includes(marketParams?.loanToken.toLowerCase()) ||
        wrapped.includes(marketParams?.loanToken.toLowerCase()) ||
        ERC20Mintable.includes(marketParams?.loanToken.toLowerCase()))
    ) {
      showLoanToken = true;
    }
    if (
      marketParams?.collateralToken &&
      (mockTokens.includes(marketParams?.collateralToken.toLowerCase()) ||
        wrapped.includes(marketParams?.collateralToken.toLowerCase()) ||
        ERC20Mintable.includes(marketParams?.collateralToken.toLowerCase()))
    ) {
      showCollateralToken = true;
    }

    if (!showLoanToken && !showCollateralToken) {
      return null;
    }
    return (
      <Box
        display="flex"
        flexDirection="column"
        alignItems="center"
        justifyContent="center"
        marginTop={1}
      >
        <Box sx={{ fontWeight: "bold" }} style={{ marginTop: "24px" }}>
          {"Faucet functionality:"}
        </Box>
        {showLoanToken &&
          marketParams?.loanToken &&
          faucetTokens(marketParams.loanToken.toLowerCase(), "loan")}
        {showCollateralToken &&
          marketParams?.collateralToken &&
          faucetTokens(
            marketParams.collateralToken.toLowerCase(),
            "collateral"
          )}
      </Box>
    );
  }

  // function renderSome(): ReactNode {
  //   if (account.isConnected && account.chainId) {
  //     return (
  //       <div>
  //         <p>{marketParams?.collateralToken}</p>
  //         <p>{marketParams?.loanToken}</p>
  //         <p>{marketParams?.oracle}</p>
  //         <p>{marketParams?.irm}</p>
  //         <p>{marketParams?.lltv}</p>
  //       </div>
  //     );
  //   }
  //   return [];
  // }

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
            {marketParams
              ? `Market loan token: ${marketParams.loanToken}`
              : "Market params loading..."}
          </Typography>
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {marketParams
              ? `Market collateral token: ${marketParams?.collateralToken}`
              : "Market params loading..."}
          </Typography>
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {marketParams
              ? `Market oracle: ${marketParams?.oracle}`
              : "Market params loading..."}
          </Typography>
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {marketParams
              ? `Market irm: ${marketParams?.irm}`
              : "Market params loading..."}
          </Typography>
          <Typography
            fontSize={"16px"}
            variant="caption"
            noWrap
            sx={{ flex: 1 }}
            style={{ marginTop: "24px" }}
          >
            {marketParams
              ? `Market lltv: ${marketParams?.lltv}`
              : "Market params loading..."}
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
                  BigInt(position.supplyShares),
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
                  BigInt(position.borrowShares),
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
              ? `Position in collateral: ${formatUnits(
                  BigInt(position.collateral),
                  decimal
                )}`
              : "Collateral position loading..."}
          </Typography>
        </Box>
      </main>

      <footer className={styles.footer}></footer>
    </div>
  );
};

export default Home;
