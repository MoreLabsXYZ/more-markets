export const markets = [
    "0x04f54541d191a903c38ddb5a8197668d1a4053b7f8415b05836234cc62675f3c",
    "0x3b37604d58369d9b8eb814e1e561958ee9ecdbee3330c94e278cdcb95906d5aa",
    "0xb089388773e6581760c308a0dda8c5af144bd1da7e4fd488aa5377a502bc4f04"
]

type MarketParams = {
    [key: string]: { loanToken: string; collateralToken: string; oracle: string; irm: string; lltv: number };
}

export const marketParams: MarketParams = {
    ["0x04f54541d191a903c38ddb5a8197668d1a4053b7f8415b05836234cc62675f3c"]: {
        loanToken: "0x7Aa1Dc017f67f22469BEe3f4be733b2d41EEf485",
        collateralToken: "0x5F37B448c318D3FC381A80049e69CBC9185E51C4",
        oracle:"0xC1aB56955958Ac8379567157740F18AAadD8cD04",
        irm:"0xFF27c75791D3C3d26070A4364352adC60Fb28cff",
        lltv: 945000000000000000
    },
    ["0x3b37604d58369d9b8eb814e1e561958ee9ecdbee3330c94e278cdcb95906d5aa"]: {
        loanToken: "0xbD207f23850baBe9b13e4a9d3b7bEF46A8F62c59",
        collateralToken: "0x5F37B448c318D3FC381A80049e69CBC9185E51C4",
        oracle:"0xC1aB56955958Ac8379567157740F18AAadD8cD04",
        irm:"0xFF27c75791D3C3d26070A4364352adC60Fb28cff",
        lltv: 945000000000000000
    },
    ["0xb089388773e6581760c308a0dda8c5af144bd1da7e4fd488aa5377a502bc4f04"]: {
        loanToken: "0x7Aa1Dc017f67f22469BEe3f4be733b2d41EEf485",
        collateralToken: "0x5F37B448c318D3FC381A80049e69CBC9185E51C4",
        oracle:"0xC1aB56955958Ac8379567157740F18AAadD8cD04",
        irm:"0x0000000000000000000000000000000000000000",
        lltv: 945000000000000000
    }
}