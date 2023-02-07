// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../BaseTest.test.sol";
import { SafeERC20, IERC20 } from "../../../contracts/mock/MockTokenPermit.sol";
import { Oracle2PoolEURChainlink, IOracle, AggregatorV3Interface } from "../../../contracts/oracle/implementations/arbitrum/Oracle2PoolEURChainlink.sol";

interface IMockOracle {
    function circuitChainlink() external pure returns (AggregatorV3Interface[] memory);
}

contract OracleArbitrumTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IOracle public oracle2Pool;
    ITreasury public TREASURY = ITreasury(0x0D710512E100C171139D2Cf5708f22C680eccF52);
    uint32 public constant STALE_PERIOD = 3600 * 24;

    uint256 public constant BTC_PRICE = 18_500;
    uint256 public constant ETH_PRICE = 1300;
    uint256 public constant EUR_PRICE = 10000;
    uint256 internal constant _BPS = 10000;
    uint256 internal constant _DEV_BPS = 100;

    function setUp() public override {
        super.setUp();
        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_ARBITRUM"), 58545851);
        vm.selectFork(_ethereum);

        oracle2Pool = new Oracle2PoolEURChainlink(STALE_PERIOD, address(TREASURY));
    }

    // ================================== READ ==================================

    function testRead2Pool() public {
        uint256 lpPriceInEUR = oracle2Pool.read();
        console.log("our lowerbound lpPriceInEUR ", lpPriceInEUR);

        AggregatorV3Interface[] memory chainlinkAddress = IMockOracle(address(oracle2Pool)).circuitChainlink();
        assertEq(address(chainlinkAddress[0]), 0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7);
        assertEq(address(chainlinkAddress[1]), 0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3);
        assertEq(address(chainlinkAddress[2]), 0xA14d53bC1F1c0F31B4aA3BD109344E5009051a84);

        (, int256 USDEUR, , , ) = chainlinkAddress[2].latestRoundData();
        uint256 lpPriceInUSD = (lpPriceInEUR * uint256(USDEUR)) / 10**8;

        assertGe(lpPriceInUSD, (1.01e18 * (_BPS - _DEV_BPS)) / _BPS);
        assertLe(lpPriceInUSD, (1.01e18 * (_BPS + _DEV_BPS)) / _BPS);
    }
}
