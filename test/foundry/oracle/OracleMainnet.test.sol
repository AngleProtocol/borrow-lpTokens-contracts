// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../BaseTest.test.sol";
import { SafeERC20, IERC20 } from "../../../contracts/mock/MockTokenPermit.sol";
import { OracleCrvUSDBTCETHEUR, IOracle, AggregatorV3Interface } from "../../../contracts/oracle/implementations/polygon/OracleCrvUSDBTCETHEUR.sol";
import { OracleBalancerSTETHChainlink } from "../../../contracts/oracle/implementations/mainnet/OracleBalancerSTETHChainlink.sol";
import { OracleFRAXBPEURChainlink } from "../../../contracts/oracle/implementations/mainnet/OracleFRAXBPEURChainlink.sol";
import { Oracle3CRVEURChainlink } from "../../../contracts/oracle/implementations/mainnet/Oracle3CRVEURChainlink.sol";
import { OracleLUSD3CRVEURChainlink } from "../../../contracts/oracle/implementations/mainnet/OracleLUSD3CRVEURChainlink.sol";

interface IMockOracle {
    function circuitChainlink() external pure returns (AggregatorV3Interface[] memory);
}

contract OracleMainnetTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IOracle public oracleBalancerSTETH;
    IOracle public oracleFRAXBP;
    IOracle public oracle3CRV;
    IOracle public oracleLUSD3CRV;
    ITreasury public TREASURY = ITreasury(0x8667DBEBf68B0BFa6Db54f550f41Be16c4067d60);
    uint32 public constant STALE_PERIOD = 3600 * 24;

    uint256 public constant BTC_PRICE = 18_500;
    uint256 public constant ETH_PRICE = 1300;
    uint256 public constant EUR_PRICE = 10000;
    uint256 internal constant _BPS = 10000;
    uint256 internal constant _DEV_BPS = 100;

    function setUp() public override {
        super.setUp();
        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 16127107);
        vm.selectFork(_ethereum);

        oracleBalancerSTETH = new OracleBalancerSTETHChainlink(STALE_PERIOD, address(TREASURY));
        oracleFRAXBP = new OracleFRAXBPEURChainlink(STALE_PERIOD, address(TREASURY));
        oracle3CRV = new Oracle3CRVEURChainlink(STALE_PERIOD, address(TREASURY));
        oracleLUSD3CRV = new OracleLUSD3CRVEURChainlink(STALE_PERIOD, address(TREASURY));
    }

    // ================================== READ ==================================

    function testReadBalancerSTETH() public {
        uint256 lpPriceInEUR = oracleBalancerSTETH.read();
        console.log("our lowerbound lpPriceInEUR ", lpPriceInEUR);

        AggregatorV3Interface[] memory chainlinkAddress = IMockOracle(address(oracleBalancerSTETH)).circuitChainlink();
        assertEq(address(chainlinkAddress[0]), 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8);
        assertEq(address(chainlinkAddress[1]), 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        assertEq(address(chainlinkAddress[2]), 0xb49f677943BC038e9857d61E7d053CaA2C1734C1);
    }

    function testReadFRAXBP() public {
        uint256 lpPriceInEUR = oracleFRAXBP.read();
        console.log("our lowerbound lpPriceInEUR ", lpPriceInEUR);

        AggregatorV3Interface[] memory chainlinkAddress = IMockOracle(address(oracleFRAXBP)).circuitChainlink();
        assertEq(address(chainlinkAddress[0]), 0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD);
        assertEq(address(chainlinkAddress[1]), 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
        assertEq(address(chainlinkAddress[2]), 0xb49f677943BC038e9857d61E7d053CaA2C1734C1);
    }

    function testRead3CRV() public {
        uint256 lpPriceInEUR = oracle3CRV.read();
        AggregatorV3Interface[] memory chainlinkAddress = IMockOracle(address(oracle3CRV)).circuitChainlink();
        console.log("our lowerbound lpPriceInEUR ", lpPriceInEUR);

        assertEq(address(chainlinkAddress[0]), 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9);
        assertEq(address(chainlinkAddress[1]), 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
        assertEq(address(chainlinkAddress[2]), 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
        assertEq(address(chainlinkAddress[3]), 0xb49f677943BC038e9857d61E7d053CaA2C1734C1);

        (, int256 USDEUR, , , ) = chainlinkAddress[3].latestRoundData();
        uint256 lpPriceInUSD = (lpPriceInEUR * uint256(USDEUR)) / 10**8;

        console.log("our lowerbound lpPriceInUSD ", lpPriceInUSD);

        assertGe(lpPriceInUSD, (1.02e18 * (_BPS - _DEV_BPS)) / _BPS);
        assertLe(lpPriceInUSD, (1.02e18 * (_BPS + _DEV_BPS)) / _BPS);
    }

    function testReadLUSD3CRV() public {
        uint256 lpPriceInEUR = oracleLUSD3CRV.read();
        AggregatorV3Interface[] memory chainlinkAddress = IMockOracle(address(oracleLUSD3CRV)).circuitChainlink();
        console.log("our lowerbound lpPriceInEUR ", lpPriceInEUR);

        assertEq(address(chainlinkAddress[0]), 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9);
        assertEq(address(chainlinkAddress[1]), 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6);
        assertEq(address(chainlinkAddress[2]), 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D);
        assertEq(address(chainlinkAddress[3]), 0x3D7aE7E594f2f2091Ad8798313450130d0Aba3a0);
        assertEq(address(chainlinkAddress[4]), 0xb49f677943BC038e9857d61E7d053CaA2C1734C1);

        (, int256 USDEUR, , , ) = chainlinkAddress[4].latestRoundData();
        uint256 lpPriceInUSD = (lpPriceInEUR * uint256(USDEUR)) / 10**8;

        assertGe(lpPriceInUSD, (1.04e18 * (_BPS - _DEV_BPS)) / _BPS);
        assertLe(lpPriceInUSD, (1.04e18 * (_BPS + _DEV_BPS)) / _BPS);
    }
}
