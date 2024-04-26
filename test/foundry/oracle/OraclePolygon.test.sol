// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../BaseTest.test.sol";
import { SafeERC20 } from "borrow-staked/mock/MockTokenPermit.sol";
import { OracleCrvUSDBTCETHEUR, IOracle, AggregatorV3Interface } from "borrow-staked/oracle/implementations/polygon/OracleCrvUSDBTCETHEUR.sol";
import { OracleAaveUSDBPEUR } from "borrow-staked/oracle/implementations/polygon/OracleAaveUSDBPEUR.sol";
import "borrow-staked/interfaces/external/curve/ITricryptoPool.sol";
import "borrow-staked/interfaces/external/curve/ICurveCryptoSwapPool.sol";

interface ICurvePoolBalance is IERC20 {
    function balances(uint256 index) external view returns (uint256);
}

interface IMockOracle {
    function circuitChainlink() external pure returns (AggregatorV3Interface[] memory);
}

contract OraclePolygonTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IOracle public oracleTriCrypto;
    IOracle public oracleAaveBp;
    ITreasury public TREASURY = ITreasury(0x2F2e0ba9746aae15888cf234c4EB5B301710927e);
    ITricryptoPool public constant TRI_CRYPTO_POOL = ITricryptoPool(0x92215849c439E1f8612b6646060B4E3E5ef822cC);
    IERC20 public constant TRI_CRYPTO_LP = IERC20(0xdAD97F7713Ae9437fa9249920eC8507e5FbB23d3);
    ICurveCryptoSwapPool public constant AaveBP = ICurveCryptoSwapPool(0x445FE580eF8d70FF569aB36e80c647af338db351);
    IERC20 public constant AAVE_BP_LP = IERC20(0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171);
    uint32 public constant STALE_PERIOD = 3600 * 24;

    uint256 public constant BTC_PRICE = 18_500;
    uint256 public constant ETH_PRICE = 1300;
    uint256 public constant EUR_PRICE = 10000;
    uint256 internal constant _BPS = 10000;

    function setUp() public override {
        super.setUp();
        _polygon = vm.createFork(vm.envString("ETH_NODE_URI_POLYGON"), 35388701);
        vm.selectFork(_polygon);

        oracleTriCrypto = new OracleCrvUSDBTCETHEUR(STALE_PERIOD, address(TREASURY));
        oracleAaveBp = new OracleAaveUSDBPEUR(STALE_PERIOD, address(TREASURY));
    }

    // ================================== READ ==================================

    function testReadTricryptoPool() public {
        {
            /*
            uint256 usdTotal = ((uint256(1064545) * uint256(8133834303140886875013829)) /
                10**24 +
                (uint256(18441) * uint256(48020677053)) /
                10**8 +
                (uint256(1267) * uint256(6950798106072563439294)) /
                10**18);
            uint256 truePrice = (usdTotal * 10**18) / 29396520412868861416651;
            console.log("api usd total ", usdTotal);
            console.log("api price ", truePrice);
            */
        }
        uint256 lpAaveBPGrossPrice;
        {
            uint256 daiAmount = ICurvePoolBalance(address(AaveBP)).balances(0);
            uint256 usdcAmount = ICurvePoolBalance(address(AaveBP)).balances(1);
            uint256 usdtAmount = ICurvePoolBalance(address(AaveBP)).balances(2);
            uint256 totSupplyAaveBP = AAVE_BP_LP.totalSupply();
            lpAaveBPGrossPrice =
                ((daiAmount + usdcAmount * 10 ** 12 + usdtAmount * 10 ** 12) * 10 ** 18) /
                totSupplyAaveBP;

            // console.log("lpAaveBPGrossPrice ", lpAaveBPGrossPrice);
        }

        uint256 lpTriGrossPrice;
        {
            uint256 lpAaveBPAmount = ICurvePoolBalance(address(TRI_CRYPTO_POOL)).balances(0);
            uint256 wbtcAmount = ICurvePoolBalance(address(TRI_CRYPTO_POOL)).balances(1);
            uint256 ethAmount = ICurvePoolBalance(address(TRI_CRYPTO_POOL)).balances(2);
            uint256 totSupplyTri = TRI_CRYPTO_LP.totalSupply();
            lpTriGrossPrice =
                (_BPS *
                    (((lpAaveBPAmount * lpAaveBPGrossPrice) /
                        10 ** 18 +
                        wbtcAmount *
                        BTC_PRICE *
                        10 ** 10 +
                        ethAmount *
                        ETH_PRICE) * 10 ** 18)) /
                totSupplyTri /
                EUR_PRICE;

            // console.log("estimated usd total ", (lpTriGrossPrice * totSupplyTri * EUR_PRICE) / 10**36);
            // console.log("total supply ", totSupplyTri / 10**18);
        }

        // console.log("lpTriGrossPrice ", lpTriGrossPrice);

        uint256 lpPriceInEUR = oracleTriCrypto.read();
        console.log("lpPriceInEUR ", lpPriceInEUR);

        AggregatorV3Interface[] memory chainlinkAddress = IMockOracle(address(oracleTriCrypto)).circuitChainlink();
        assertEq(address(chainlinkAddress[0]), 0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D);
        assertEq(address(chainlinkAddress[1]), 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7);
        assertEq(address(chainlinkAddress[2]), 0x0A6513e40db6EB1b165753AD52E80663aeA50545);
        assertEq(address(chainlinkAddress[3]), 0x73366Fe0AA0Ded304479862808e02506FE556a98);

        // assertEq(lpPriceInEUR, lpTriGrossPrice);
    }

    function testReadAaveUSDBPPool() public {
        uint256 lpAaveBPGrossPrice;
        {
            uint256 daiAmount = ICurvePoolBalance(address(AaveBP)).balances(0);
            uint256 usdcAmount = ICurvePoolBalance(address(AaveBP)).balances(1);
            uint256 usdtAmount = ICurvePoolBalance(address(AaveBP)).balances(2);
            uint256 totSupplyAaveBP = AAVE_BP_LP.totalSupply();
            lpAaveBPGrossPrice =
                ((daiAmount + usdcAmount * 10 ** 12 + usdtAmount * 10 ** 12) * 10 ** 18) /
                totSupplyAaveBP;

            console.log("lp gross price in USD:", lpAaveBPGrossPrice);
        }

        lpAaveBPGrossPrice = (lpAaveBPGrossPrice * _BPS) / EUR_PRICE;
        console.log("lp gross price in EUR ", lpAaveBPGrossPrice);

        uint256 lpPriceInEUR = oracleAaveBp.read();
        console.log("our lowerbound lpPriceInEUR ", lpPriceInEUR);

        AggregatorV3Interface[] memory chainlinkAddress = IMockOracle(address(oracleAaveBp)).circuitChainlink();
        assertEq(address(chainlinkAddress[0]), 0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D);
        assertEq(address(chainlinkAddress[1]), 0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7);
        assertEq(address(chainlinkAddress[2]), 0x0A6513e40db6EB1b165753AD52E80663aeA50545);
        assertEq(address(chainlinkAddress[3]), 0x73366Fe0AA0Ded304479862808e02506FE556a98);

        // assertGe(lpAaveBPGrossPrice, lpPriceInEUR);
    }
}
