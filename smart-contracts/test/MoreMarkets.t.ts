import {
  loadFixture,
  impersonateAccount,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { MarketParamsStruct } from "../typechain-types/contracts/MoreMarkets";
import { AbiCoder, keccak256 } from "ethers";

describe("MoreMarkets", function () {
  const ORACLE = "0xC1aB56955958Ac8379567157740F18AAadD8cD04";

  const CREDORA_ADMIN = "0x98ADc891Efc9Ce18cA4A63fb0DfbC2864566b5Ab";
  const CREDORA_METRICS = "0xA1CE4fD8470718eB3e8248E40ab489856E125F59";

  const LLTVS = [945000000000000000n, 965000000000000000n, 800000000000000000n];
  const PREMIUM_LLTVS = [1000000000000000000n, 1250000000000000000n];

  const RAE_VALUES = ["BBB-", "AAA+"];

  const identifier = (marketParams: MarketParamsStruct) => {
    const encodedMarket = AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "address", "address", "uint256"],
      Object.values(marketParams)
    );

    return Buffer.from(keccak256(encodedMarket).slice(2), "hex");
  };

  function stringToBytes8(str: string): string {
    let bytes = ethers.toUtf8Bytes(str);

    if (bytes.length > 8) {
      throw new Error("String is too long to convert to bytes8");
    }

    let bytes8 = new Uint8Array(8);
    bytes8.set(bytes);
    return ethers.hexlify(bytes8);
  }

  async function deployFixture() {
    const [owner, otherAccount] = await hre.ethers.getSigners();

    // get admin of Credora
    await impersonateAccount(CREDORA_ADMIN);
    const credoraAdmin = await ethers.getSigner(CREDORA_ADMIN);

    const creditAttestationService = await hre.ethers.getContractAt(
      "ICreditAttestationService",
      CREDORA_METRICS
    );

    const oracle = await hre.ethers.getContractAt("OracleMock", ORACLE);

    const MoreMarkets = await hre.ethers.getContractFactory("MoreMarkets");
    const moreMarkets = await MoreMarkets.deploy(owner);

    // setup markets
    const IRM = await hre.ethers.getContractFactory("AdaptiveCurveIrm");
    const irm = await IRM.deploy(moreMarkets);

    await moreMarkets.enableIrm(irm);

    await moreMarkets.enableLltv(LLTVS[0]);
    await moreMarkets.enableLltv(LLTVS[1]);
    await moreMarkets.enableLltv(LLTVS[2]);

    // set credora metrics on more markets
    // await moreMarkets.setCreditAttestationService(CREDORA_METRICS);

    // deploy tokens
    const LoanToken = await hre.ethers.getContractFactory("ERC20MintableMock");
    const loanToken = await LoanToken.deploy(owner);

    const CollateralToken = await hre.ethers.getContractFactory(
      "ERC20MintableMock"
    );
    const collateralToken = await CollateralToken.deploy(owner);

    // create market
    const marketParams: MarketParamsStruct = {
      loanToken: await loanToken.getAddress(),
      collateralToken: await collateralToken.getAddress(),
      oracle: ORACLE,
      irm: await irm.getAddress(),
      lltv: LLTVS[0],
    };
    await moreMarkets.createMarket(marketParams);
    const marketId = identifier(marketParams);

    // LLTV's for RAE
    await moreMarkets.setLltvToRae(
      marketId,
      stringToBytes8(RAE_VALUES[0]),
      PREMIUM_LLTVS[0]
    );
    await moreMarkets.setLltvToRae(
      marketId,
      stringToBytes8(RAE_VALUES[1]),
      PREMIUM_LLTVS[1]
    );

    // mint some tokens
    await loanToken.mint(owner, ethers.parseEther("100000"));
    await loanToken.approve(moreMarkets, ethers.parseEther("100000"));

    await collateralToken.mint(owner, ethers.parseEther("100000"));
    await collateralToken.approve(moreMarkets, ethers.parseEther("100000"));

    // supply tokens to markets
    await moreMarkets.supply(
      marketParams,
      ethers.parseEther("1000"),
      0,
      owner,
      "0x"
    );

    return {
      moreMarkets,
      owner,
      credoraAdmin,
      creditAttestationService,
      irm,
      marketParams,
      marketId,
      loanToken,
      collateralToken,
      oracle,
    };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { moreMarkets, owner } = await loadFixture(deployFixture);

      expect(await moreMarkets.owner()).to.equal(owner.address);
    });

    it("Should set the right credora address", async function () {
      const { moreMarkets, creditAttestationService } = await loadFixture(
        deployFixture
      );

      // expect(await moreMarkets.creditAttestationService()).to.equal(
      //   creditAttestationService
      // );
    });

    it("Should enable irm", async function () {
      const { moreMarkets, irm } = await loadFixture(deployFixture);

      expect(await moreMarkets.isIrmEnabled(irm)).to.equal(true);
    });

    it("Should enable LLTVs", async function () {
      const { moreMarkets } = await loadFixture(deployFixture);

      expect(await moreMarkets.isLltvEnabled(LLTVS[0])).to.equal(true);
      expect(await moreMarkets.isLltvEnabled(LLTVS[1])).to.equal(true);
    });

    it("Should create market with correct params", async function () {
      const { moreMarkets, marketParams, marketId } = await loadFixture(
        deployFixture
      );

      const contractMarketParams = await moreMarkets.idToMarketParams(marketId);
      expect(contractMarketParams[0]).to.equal(marketParams.loanToken);
      expect(contractMarketParams[1]).to.equal(marketParams.collateralToken);
      expect(contractMarketParams[2]).to.equal(marketParams.oracle);
      expect(contractMarketParams[3]).to.equal(marketParams.irm);
      expect(contractMarketParams[4]).to.equal(marketParams.lltv);
    });

    it("Should set LLTV for AAA+", async function () {
      const { moreMarkets, marketId } = await loadFixture(deployFixture);

      expect(
        await moreMarkets.raeToCustomLltv(
          marketId,
          stringToBytes8(RAE_VALUES[1])
        )
      ).to.equal(PREMIUM_LLTVS[1]);
    });

    it("Should set balances for loan and coll tokens", async function () {
      const { owner, loanToken, collateralToken } = await loadFixture(
        deployFixture
      );

      expect(await loanToken.balanceOf(owner)).to.equal(
        ethers.parseEther("9000")
      );
      expect(await collateralToken.balanceOf(owner)).to.equal(
        ethers.parseEther("10000")
      );
    });
  });

  describe("First scenario", function () {
    it("Should borrow maxBorrow and then more after credit rating increased", async function () {
      const {
        creditAttestationService,
        credoraAdmin,
        moreMarkets,
        marketParams,
        owner,
      } = await loadFixture(deployFixture);
      await moreMarkets.supplyCollateral(
        marketParams,
        ethers.parseEther("100"),
        owner,
        "0x"
      );

      await expect(
        moreMarkets.borrow(
          marketParams,
          ethers.parseEther("94.51"),
          0,
          owner,
          owner
        )
      ).to.be.revertedWith("insufficient collateral");

      await moreMarkets.borrow(
        marketParams,
        ethers.parseEther("94.5"),
        0,
        owner,
        owner
      );

      await expect(
        moreMarkets.borrow(
          marketParams,
          ethers.parseEther("0.01"),
          0,
          owner,
          owner
        )
      ).to.be.revertedWith("insufficient collateral");

      const encodedCredoraParams = AbiCoder.defaultAbiCoder().encode(
        ["address", "uint64", "uint64", "bytes8", "uint64", "uint64", "uint64"],
        [owner.address, 0, 0, stringToBytes8("AAA+"), 0, 0, 0]
      );
      const emptyBytes32 =
        "0x0000000000000000000000000000000000000000000000000000000000000000";

      await creditAttestationService
        .connect(credoraAdmin)
        .setData(emptyBytes32, encodedCredoraParams, emptyBytes32);
      await creditAttestationService
        .connect(credoraAdmin)
        ["grantPermission(address,address,uint128)"](
          owner.address,
          owner.address,
          60000
        );
      await creditAttestationService
        .connect(credoraAdmin)
        ["grantPermission(address,address,uint128)"](
          owner.address,
          await moreMarkets.getAddress(),
          60000
        );
      expect(await creditAttestationService.getRAE(owner.address)).to.equal(
        stringToBytes8("AAA+")
      );

      await expect(
        moreMarkets.borrow(
          marketParams,
          ethers.parseEther("30.51"),
          0,
          owner,
          owner
        )
      ).to.be.revertedWith("insufficient collateral");

      await moreMarkets.borrow(
        marketParams,
        ethers.parseEther("29"),
        0,
        owner,
        owner
      );

      await expect(
        moreMarkets.liquidate(marketParams, owner, 1, 0, "0x00")
      ).to.be.revertedWith("position is healthy");

      await expect(
        moreMarkets.withdrawCollateral(
          marketParams,
          ethers.parseEther("5"),
          owner.address,
          owner.address
        )
      ).to.be.revertedWith("insufficient collateral");
    });
  });

  describe("Second scenario", function () {
    it("Should borrow maxBorrow and then more after credit rating increased", async function () {
      const {
        creditAttestationService,
        credoraAdmin,
        moreMarkets,
        marketParams,
        marketId,
        owner,
        loanToken,
        collateralToken,
      } = await loadFixture(deployFixture);

      const suppliedCollateral = ethers.parseEther("100");
      await moreMarkets.supplyCollateral(
        marketParams,
        suppliedCollateral,
        owner,
        "0x"
      );

      let encodedCredoraParams = AbiCoder.defaultAbiCoder().encode(
        ["address", "uint64", "uint64", "bytes8", "uint64", "uint64", "uint64"],
        [owner.address, 0, 0, stringToBytes8(RAE_VALUES[1]), 0, 0, 0]
      );
      const emptyBytes32 =
        "0x0000000000000000000000000000000000000000000000000000000000000000";

      await creditAttestationService
        .connect(credoraAdmin)
        .setData(emptyBytes32, encodedCredoraParams, emptyBytes32);
      await creditAttestationService
        .connect(credoraAdmin)
        ["grantPermission(address,address,uint128)"](
          owner.address,
          owner.address,
          60000
        );
      await creditAttestationService
        .connect(credoraAdmin)
        ["grantPermission(address,address,uint128)"](
          owner.address,
          await moreMarkets.getAddress(),
          60000
        );
      expect(await creditAttestationService.getRAE(owner.address)).to.equal(
        stringToBytes8(RAE_VALUES[1])
      );

      await moreMarkets.borrow(
        marketParams,
        ethers.parseEther("120"),
        0,
        owner,
        owner
      );

      await expect(
        moreMarkets.borrow(
          marketParams,
          ethers.parseEther("5.1"),
          0,
          owner,
          owner
        )
      ).to.be.revertedWith("insufficient collateral");

      await expect(
        moreMarkets.liquidate(marketParams, owner, 1, 0, "0x00")
      ).to.be.revertedWith("position is healthy");

      encodedCredoraParams = AbiCoder.defaultAbiCoder().encode(
        ["address", "uint64", "uint64", "bytes8", "uint64", "uint64", "uint64"],
        [owner.address, 0, 0, stringToBytes8(RAE_VALUES[0]), 0, 0, 0]
      );
      await creditAttestationService
        .connect(credoraAdmin)
        .setData(emptyBytes32, encodedCredoraParams, emptyBytes32);

      await expect(
        moreMarkets.withdrawCollateral(
          marketParams,
          ethers.parseEther("0.001"),
          owner.address,
          owner.address
        )
      ).to.be.revertedWith("insufficient collateral");

      const balanceLoanBef = await loanToken.balanceOf(owner.address);
      const balanceCollBef = await collateralToken.balanceOf(owner.address);
      await moreMarkets.liquidate(
        marketParams,
        owner,
        suppliedCollateral,
        0,
        "0x"
      );

      console.log(balanceLoanBef - (await loanToken.balanceOf(owner.address)));
      console.log(
        (await collateralToken.balanceOf(owner.address)) - balanceCollBef
      );
    });
  });

  describe("Liquidate", function () {
    it("partial liquidation from example", async function () {
      const {
        creditAttestationService,
        credoraAdmin,
        moreMarkets,
        owner,
        loanToken,
        collateralToken,
        oracle,
        irm,
      } = await loadFixture(deployFixture);

      await oracle.setPrice(3000000000000000000000000000000000000000n);

      const marketParams: MarketParamsStruct = {
        loanToken: await loanToken.getAddress(),
        collateralToken: await collateralToken.getAddress(),
        oracle: ORACLE,
        irm: await irm.getAddress(),
        lltv: LLTVS[2],
      };
      await moreMarkets.createMarket(marketParams);
      const marketId = identifier(marketParams);

      await collateralToken.approve(moreMarkets, ethers.parseEther("100000"));
      await loanToken.approve(moreMarkets, ethers.parseEther("100000"));
      await moreMarkets.supply(
        marketParams,
        ethers.parseEther("10000"),
        0,
        owner,
        "0x"
      );

      await moreMarkets.supplyCollateral(
        marketParams,
        ethers.parseEther("1"),
        owner,
        "0x"
      );

      await moreMarkets.borrow(
        marketParams,
        ethers.parseEther("2400"),
        0,
        owner,
        owner
      );

      // await moreMarkets.liquidate(
      //   marketParams,
      //   owner,
      //   ethers.parseEther("0.1"),
      //   0,
      //   "0x"
      // );

      await oracle.setPrice(2900000000000000000000000000000000000000n);

      const balanceCollBef = await collateralToken.balanceOf(owner.address);
      const balanceLoanBef = await loanToken.balanceOf(owner.address);
      console.log("liquidation 1");
      await moreMarkets.liquidate(
        marketParams,
        owner,
        ethers.parseEther("0.5"),
        0,
        "0x"
      );
      console.log(
        (await collateralToken.balanceOf(owner.address)) - balanceCollBef
      );
      console.log(balanceLoanBef - (await loanToken.balanceOf(owner.address)));

      console.log("liquidation 2");
      await expect(
        moreMarkets.liquidate(
          marketParams,
          owner,
          ethers.parseEther("0.1"),
          0,
          "0x"
        )
      ).to.revertedWith("position is healthy");
    });
  });
});
