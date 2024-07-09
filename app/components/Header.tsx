import Link from "next/link";
import { ConnectButton, getDefaultConfig } from "@rainbow-me/rainbowkit";
import styles from "../styles/Home.module.css";
import {
  AppBar,
  Box,
  Button,
  Icon,
  IconButton,
  Toolbar,
  Typography,
  styled,
} from "@mui/material";
import { useAccount, useAccountEffect } from "wagmi";
import { Chain, formatUnits } from "viem";
import { flowPreviewnet } from "viem/chains";
import { readContract } from "wagmi/actions";
import { CredoraMetricsAbi } from "../abi/CredoraMetricsAbi";
import { useEffect, useState } from "react";

const Header = () => {
  const account = useAccount();
  const [credoraScore, setCredoraScore] = useState(0);
  const [credoraNav, setCredoraNav] = useState(0);
  const [credoraRAE, setCredoraRAE] = useState("");
  const [credoraBorrowCapacity, setCredoraBorrowCapacity] = useState(0);
  const [credoraImpliedPD, setCredoraImpliedPD] = useState(0);
  const [credoraImpliedPDTenor, setCredoraImpliedPDTenor] = useState(0);
  const [isPremium, setIsPremium] = useState(false);

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

  useAccountEffect({
    onConnect() {
      getCredoraParams();
    },
    onDisconnect() {
      setIsPremium(false);
    },
  });

  // useEffect(() => {
  //   console.log("credoraParams: ", credoraParams);
  // }, [credoraParams]);

  const getCredoraParams = async () => {
    let score: any;
    let NAV: any;
    let RAE: any;
    let borrowCapacity: any;
    let impliedPD: any;
    let impliedPDTenor: any;
    try {
      score = await readContract(config, {
        address: "0xA1CE4fD8470718eB3e8248E40ab489856E125F59",
        abi: CredoraMetricsAbi,
        functionName: "getScore",
        chainId: sepolia.id,
        args: [account.address],
        account: "0x3A97Be8782027f2d6E2c919C3fc5D47bcc61c167",
      });
      setCredoraScore(score);
    } catch (e) {
      console.log(e);
    }
    try {
      const NAV: any = await readContract(config, {
        address: "0xA1CE4fD8470718eB3e8248E40ab489856E125F59",
        abi: CredoraMetricsAbi,
        functionName: "getNAV",
        chainId: sepolia.id,
        args: [account.address],
        account: "0x3A97Be8782027f2d6E2c919C3fc5D47bcc61c167",
      });
      setCredoraNav(NAV);
    } catch (e) {
      console.log(e);
    }

    try {
      RAE = await readContract(config, {
        address: "0xA1CE4fD8470718eB3e8248E40ab489856E125F59",
        abi: CredoraMetricsAbi,
        functionName: "getRAE",
        chainId: sepolia.id,
        args: [account.address],
        account: "0x3A97Be8782027f2d6E2c919C3fc5D47bcc61c167",
      });
      setCredoraRAE(bytes8ToString(RAE));
    } catch (e) {
      console.log(e);
    }
    try {
      borrowCapacity = await readContract(config, {
        address: "0xA1CE4fD8470718eB3e8248E40ab489856E125F59",
        abi: CredoraMetricsAbi,
        functionName: "getBorrowCapacity",
        chainId: sepolia.id,
        args: [account.address],
        account: "0x3A97Be8782027f2d6E2c919C3fc5D47bcc61c167",
      });
      setCredoraBorrowCapacity(borrowCapacity);
    } catch (e) {
      console.log(e);
    }
    try {
      impliedPD = await readContract(config, {
        address: "0xA1CE4fD8470718eB3e8248E40ab489856E125F59",
        abi: CredoraMetricsAbi,
        functionName: "getImpliedPD",
        chainId: sepolia.id,
        args: [account.address],
        account: "0x3A97Be8782027f2d6E2c919C3fc5D47bcc61c167",
      });
      setCredoraImpliedPD(impliedPD);
    } catch (e) {
      console.log(e);
    }
    try {
      impliedPDTenor = await readContract(config, {
        address: "0xA1CE4fD8470718eB3e8248E40ab489856E125F59",
        abi: CredoraMetricsAbi,
        functionName: "getImpliedPDTenor",
        chainId: sepolia.id,
        args: [account.address],
        account: "0x3A97Be8782027f2d6E2c919C3fc5D47bcc61c167",
      });
      setCredoraImpliedPDTenor(impliedPDTenor);
    } catch (e) {
      console.log(e);
    }
    console.log("score: ", score);
    console.log("NAV: ", NAV);
    console.log("RAE: ", RAE ? bytes8ToString(RAE) : RAE);
    console.log("borrowCapacity: ", borrowCapacity);
    console.log("impliedPD: ", impliedPD);
    console.log("impliedPDTenor: ", impliedPDTenor);
    if (score || NAV || RAE || borrowCapacity || impliedPD || impliedPDTenor) {
      setIsPremium(true);
    } else {
      setIsPremium(false);
    }
    // console.log("params: ", score);
    // setCredoraParams({
    //   score: score,
    //   NAV: NAV,
    //   RAE: RAE,
    //   borrowCapacity: BorrowCapacity,
    //   impliedPD: ImpliedPD,
    //   impliedPDTenor: ImpliedPDTenor,
    // });
  };

  const bytes8ToString = (bytes: string): string => {
    // Убираем префикс "0x" если он есть
    if (bytes.startsWith("0x")) {
      bytes = bytes.slice(2);
    }

    // Разделяем строку на пары символов (байты)
    const bytePairs = bytes.match(/.{1,2}/g);

    // Преобразуем каждую пару символов в символ строки
    const charArray =
      bytePairs?.map((byte) => String.fromCharCode(parseInt(byte, 16))) || [];

    // Соединяем массив символов в строку
    return charArray.join("");
  };

  return (
    <Box>
      <Box sx={{ flexGrow: 1 }}>
        <AppBar position="static">
          <Toolbar>
            <Box sx={{ flexGrow: 1, display: { xs: "none", md: "flex" } }}>
              <Button href="/" sx={{ my: 2, color: "white", display: "block" }}>
                <Typography variant="h5" component="div" sx={{ flexGrow: 1 }}>
                  More Protocol
                </Typography>
              </Button>
            </Box>
            <Box sx={{ flexGrow: 1, display: { xs: "none", md: "flex" } }}>
              <Button href="/" sx={{ my: 2, color: "white", display: "block" }}>
                <Typography component="div" sx={{ flexGrow: 1 }}>
                  Markets
                </Typography>
              </Button>
              <Button
                href="/vaultList"
                sx={{ my: 2, color: "white", display: "block" }}
              >
                <Typography component="div" sx={{ flexGrow: 1 }}>
                  Vaults
                </Typography>
              </Button>
            </Box>
            <Box
              display="flex"
              flexDirection="column"
              alignItems="center"
              justifyContent="center"
            >
              <ConnectButton />
              {isPremium ? (
                <Typography component="div" sx={{ flexGrow: 1 }} variant="h6">
                  Premium
                </Typography>
              ) : (
                <></>
              )}
            </Box>
          </Toolbar>
        </AppBar>
      </Box>
      {isPremium ? (
        <Box
          display="flex"
          flexDirection="column"
          alignItems="flex-end"
          sx={{ mr: "20px" }}
        >
          <Typography component="div" sx={{ flexGrow: 1 }}>
            Stats:
          </Typography>
          {credoraScore != 0 ? (
            <Typography component="div" sx={{ flexGrow: 1 }}>
              Score: {formatUnits(BigInt(credoraScore), 6)}
            </Typography>
          ) : (
            <></>
          )}
          {credoraRAE != "" ? (
            <Typography component="div" sx={{ flexGrow: 1 }}>
              RAE: {credoraRAE}
            </Typography>
          ) : (
            <></>
          )}
          {credoraNav != 0 ? (
            <Typography component="div" sx={{ flexGrow: 1 }}>
              NAV: {credoraNav}
            </Typography>
          ) : (
            <></>
          )}
          {credoraBorrowCapacity != 0 ? (
            <Typography component="div" sx={{ flexGrow: 1 }}>
              Borrow Capacity: {credoraBorrowCapacity}
            </Typography>
          ) : (
            <></>
          )}
          {credoraImpliedPD != 0 ? (
            <Typography component="div" sx={{ flexGrow: 1 }}>
              ImpliedPD: {credoraImpliedPD}
            </Typography>
          ) : (
            <></>
          )}
          {credoraImpliedPDTenor != 0 ? (
            <Typography component="div" sx={{ flexGrow: 1 }}>
              ImpliedPDTenor: {credoraImpliedPDTenor}
            </Typography>
          ) : (
            <></>
          )}
        </Box>
      ) : (
        <></>
      )}
    </Box>
    // <nav>
    //   <div className="flex flex-row items-center justify-between">
    //     <Link href="/">Home</Link>
    //     <ConnectButton />
    //   </div>
    // </nav>
  );
};

export default Header;
