// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../BaseTest.test.sol";
import { SafeERC20, IERC20 } from "../../../contracts/mock/MockTokenPermit.sol";
import { OracleCrvUSDBTCETHEUR, IOracle, AggregatorV3Interface } from "../../../contracts/oracle/implementations/polygon/OracleCrvUSDBTCETHEUR.sol";
import { OracleBalancerSTETHChainlink } from "../../../contracts/oracle/implementations/mainnet/OracleBalancerSTETHChainlink.sol";
import { OracleFRAXBPEURChainlink } from "../../../contracts/oracle/implementations/mainnet/OracleFRAXBPEURChainlink.sol";

interface IMockOracle {
    function circuitChainlink() external pure returns (AggregatorV3Interface[] memory);
}

contract OracleMainnetTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IOracle public oracleBalancerSTETH;
    IOracle public oracleFRAXBP;
    ITreasury public TREASURY = ITreasury(0x8667DBEBf68B0BFa6Db54f550f41Be16c4067d60);
    uint32 public constant STALE_PERIOD = 3600 * 24;

    uint256 public constant BTC_PRICE = 18_500;
    uint256 public constant ETH_PRICE = 1300;
    uint256 public constant EUR_PRICE = 10000;
    uint256 internal constant _BPS = 10000;

    function setUp() public override {
        super.setUp();
        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 16127107);
        vm.selectFork(_ethereum);

        oracleBalancerSTETH = new OracleBalancerSTETHChainlink(STALE_PERIOD, address(TREASURY));
        oracleFRAXBP = new OracleFRAXBPEURChainlink(STALE_PERIOD, address(TREASURY));
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
}
