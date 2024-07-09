import { sepolia, flowPreviewnet, polygonAmoy } from "viem/chains";

type Contracts = {
  [key: number]: { morpho: string; metaMorphoFactory: string };
};
export const contracts: Contracts = {
  [sepolia.id]: {
    morpho: "0x541cA61EE5f963B150A8c85e774d7bF8236b431E",
    metaMorphoFactory: "0xAEdd54e76E1BC044331bb372c9e3A01c0a240F20",
  },
  [flowPreviewnet.id]: {
    morpho: "0x8ffEf1310f53060049C6Ac6eD7763f0e473146cE",
    metaMorphoFactory: "0x73381B2c96A35204e61C0d336E9b09b14698aa93",
  },
  [polygonAmoy.id]: {
    morpho: "0x8ed6929bda0679A59bE264463536c90e8cCa0c06",
    metaMorphoFactory: "0xaF07b5f86Dfc1bAcf04a21DE961E2CfeB52BAbE5",
  },
};

// type MarketsInfo = { id: string };
export type Markets = {
  [key: number]: string[];
};
export const markets: Markets = {
  11155111: [
    "0x04f54541d191a903c38ddb5a8197668d1a4053b7f8415b05836234cc62675f3c",
    "0x3b37604d58369d9b8eb814e1e561958ee9ecdbee3330c94e278cdcb95906d5aa",
    "0xb089388773e6581760c308a0dda8c5af144bd1da7e4fd488aa5377a502bc4f04",
    "0xb8cbb17f3676e770f042051659584daf918d334224ecbce90cfe77874e457f3a",
  ],
  646: ["0x56d1c0e87abd6b4281ff888cc7fc1a167bd96b7f173f448d634cde490d52ea3e"],
  80002: ["0x7e223c77c5bedeec1162c0b7818232c124357f3177b5bcf13b0e1166c6a7dba0"],
};

type MarketParams = {
  [key: string]: {
    loanToken: string;
    collateralToken: string;
    oracle: string;
    irm: string;
    lltv: number;
  };
};

type ChainConfig = {
  [key: number]: MarketParams;
};

export const flowMarketParams: MarketParams = {
  "0x56d1c0e87abd6b4281ff888cc7fc1a167bd96b7f173f448d634cde490d52ea3e": {
    loanToken: "0xE621205432d56646F6552056eA8a6795741982aB",
    collateralToken: "0x204D9FbcbeC7363195A2A285821487983229Ac51",
    oracle: "0x8b8975c4A728b54aC64702b8674C5c857d4b27EB",
    irm: "0x04c43a3bDFFCb31163Cd46842FECe12BeFbC6b9C",
    lltv: 945000000000000000,
  },
};

export const amoyMarketParams: MarketParams = {
  "0x7e223c77c5bedeec1162c0b7818232c124357f3177b5bcf13b0e1166c6a7dba0": {
    loanToken: "0x60df213654533f7D4f91E75B7984cF2507Ff76A3",
    collateralToken: "0x3b2D2D4bF75784e50459fF65efAd5A93cE5766d4",
    oracle: "0x7aD1C5f906280cD5D4e29Aa0f0d8647c10447544",
    irm: "0xb53745A853a270769241A52571507e0c076666D3",
    lltv: 945000000000000000,
  },
};

export const sepoliaMarketParams: MarketParams = {
  "0x04f54541d191a903c38ddb5a8197668d1a4053b7f8415b05836234cc62675f3c": {
    loanToken: "0x7Aa1Dc017f67f22469BEe3f4be733b2d41EEf485",
    collateralToken: "0x5F37B448c318D3FC381A80049e69CBC9185E51C4",
    oracle: "0xC1aB56955958Ac8379567157740F18AAadD8cD04",
    irm: "0xFF27c75791D3C3d26070A4364352adC60Fb28cff",
    lltv: 945000000000000000,
  },
  "0x3b37604d58369d9b8eb814e1e561958ee9ecdbee3330c94e278cdcb95906d5aa": {
    loanToken: "0xbD207f23850baBe9b13e4a9d3b7bEF46A8F62c59",
    collateralToken: "0x5F37B448c318D3FC381A80049e69CBC9185E51C4",
    oracle: "0xC1aB56955958Ac8379567157740F18AAadD8cD04",
    irm: "0xFF27c75791D3C3d26070A4364352adC60Fb28cff",
    lltv: 945000000000000000,
  },
  "0xb089388773e6581760c308a0dda8c5af144bd1da7e4fd488aa5377a502bc4f04": {
    loanToken: "0x7Aa1Dc017f67f22469BEe3f4be733b2d41EEf485",
    collateralToken: "0x5F37B448c318D3FC381A80049e69CBC9185E51C4",
    oracle: "0xC1aB56955958Ac8379567157740F18AAadD8cD04",
    irm: "0x0000000000000000000000000000000000000000",
    lltv: 945000000000000000,
  },
  "0xb8cbb17f3676e770f042051659584daf918d334224ecbce90cfe77874e457f3a": {
    loanToken: "0x103433AA9EBb649b19Bb3C62A083974c5362B516",
    collateralToken: "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9",
    oracle: "0xC1aB56955958Ac8379567157740F18AAadD8cD04",
    irm: "0xFF27c75791D3C3d26070A4364352adC60Fb28cff",
    lltv: 945000000000000000,
  },
};

export const chainConfig: ChainConfig = {
  11155111: {
    "0x04f54541d191a903c38ddb5a8197668d1a4053b7f8415b05836234cc62675f3c": {
      loanToken: "0x7Aa1Dc017f67f22469BEe3f4be733b2d41EEf485",
      collateralToken: "0x5F37B448c318D3FC381A80049e69CBC9185E51C4",
      oracle: "0xC1aB56955958Ac8379567157740F18AAadD8cD04",
      irm: "0xFF27c75791D3C3d26070A4364352adC60Fb28cff",
      lltv: 945000000000000000,
    },
    "0x3b37604d58369d9b8eb814e1e561958ee9ecdbee3330c94e278cdcb95906d5aa": {
      loanToken: "0xbD207f23850baBe9b13e4a9d3b7bEF46A8F62c59",
      collateralToken: "0x5F37B448c318D3FC381A80049e69CBC9185E51C4",
      oracle: "0xC1aB56955958Ac8379567157740F18AAadD8cD04",
      irm: "0xFF27c75791D3C3d26070A4364352adC60Fb28cff",
      lltv: 945000000000000000,
    },
    "0xb089388773e6581760c308a0dda8c5af144bd1da7e4fd488aa5377a502bc4f04": {
      loanToken: "0x7Aa1Dc017f67f22469BEe3f4be733b2d41EEf485",
      collateralToken: "0x5F37B448c318D3FC381A80049e69CBC9185E51C4",
      oracle: "0xC1aB56955958Ac8379567157740F18AAadD8cD04",
      irm: "0x0000000000000000000000000000000000000000",
      lltv: 945000000000000000,
    },
    "0xb8cbb17f3676e770f042051659584daf918d334224ecbce90cfe77874e457f3a": {
      loanToken: "0x103433AA9EBb649b19Bb3C62A083974c5362B516",
      collateralToken: "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9",
      oracle: "0xC1aB56955958Ac8379567157740F18AAadD8cD04",
      irm: "0xFF27c75791D3C3d26070A4364352adC60Fb28cff",
      lltv: 945000000000000000,
    },
  },
  646: {
    "0x56d1c0e87abd6b4281ff888cc7fc1a167bd96b7f173f448d634cde490d52ea3e": {
      loanToken: "0xE621205432d56646F6552056eA8a6795741982aB",
      collateralToken: "0x204D9FbcbeC7363195A2A285821487983229Ac51",
      oracle: "0x8b8975c4A728b54aC64702b8674C5c857d4b27EB",
      irm: "0x04c43a3bDFFCb31163Cd46842FECe12BeFbC6b9C",
      lltv: 945000000000000000,
    },
  },
  80002: {
    "0x7e223c77c5bedeec1162c0b7818232c124357f3177b5bcf13b0e1166c6a7dba0": {
      loanToken: "0x60df213654533f7D4f91E75B7984cF2507Ff76A3",
      collateralToken: "0x3b2D2D4bF75784e50459fF65efAd5A93cE5766d4",
      oracle: "0x7aD1C5f906280cD5D4e29Aa0f0d8647c10447544",
      irm: "0xb53745A853a270769241A52571507e0c076666D3",
      lltv: 945000000000000000,
    },
  },
};
