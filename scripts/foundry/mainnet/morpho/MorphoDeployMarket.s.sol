// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StdCheats, StdAssertions } from "forge-std/Test.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { SwapType, BaseLevSwapper, PendleLevSwapperMorpho, Swapper } from "borrow-staked/swapper/LevSwapper/morpho/implementations/PendleLevSwapperMorphoWeETH.sol";
import "../MainnetConstants.s.sol";
import { MarketParams } from "morpho-blue/libraries/MarketParamsLib.sol";
import { IIrm } from "morpho-blue/interfaces/IIRM.sol";
import { IMorpho } from "morpho-blue/interfaces/IMorpho.sol";
import { IOracle as IMorphoOracle } from "morpho-blue/interfaces/IOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { MorphoFeedPTweETH } from "borrow/oracle/morpho/mainnet/MorphoFeedPTweETH.sol";
import { IAccessControlManager } from "borrow/interfaces/IAccessControlManager.sol";
import "borrow-staked/mock/MockCoreBorrow.sol";
import "borrow-staked/interfaces/external/morpho/IMorphoChainlinkOracleV2Factory.sol";
import { MorphoBalancesLib } from "morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import { MarketParamsLib } from "morpho-blue/libraries/MarketParamsLib.sol";

contract MorphoDeployMarket is Script, MainnetConstants, StdCheats, StdAssertions {
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    ICoreBorrow coreBorrow;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Can be changed to a new MockCoreBorrow if you want to manipulate the price
        coreBorrow = ICoreBorrow(CORE_BORROW);

        MarketParams memory params;
        bytes memory emptyData;
        address oracle;
        bytes32 salt;

        {
            // PT weETH market
            // address priceFeed = address(
            //     new MorphoFeedPTweETHDec24(IAccessControlManager(address(coreBorrow)), _MAX_IMPLIED_RATE, _TWAP_DURATION)
            // );
            address priceFeed = address(0x31dA7F6Cfc470abcc5388b6Ab5EB29df39cE0e26);
            oracle = IMorphoChainlinkOracleV2Factory(MORPHO_ORACLE_FACTORY).createMorphoChainlinkOracleV2(
                address(0),
                1,
                address(priceFeed),
                address(CHAINLINK_ETH_USD_ORACLE),
                IERC20Metadata(PTWeETHDec24).decimals(),
                address(0),
                1,
                address(0),
                address(0),
                IERC20Metadata(USDA).decimals(),
                salt
            );

            uint256 price = IMorphoOracle(oracle).price();
            // Because with the max implied rate there is a discount compared to the on chain price (3250)
            assertApproxEqRel(price, 3050 * 10 ** 36, 100 ** 36);
            params.collateralToken = PTWeETHDec24;
            params.lltv = LLTV_86;
            params.irm = IRM_MODEL;
            params.oracle = oracle;
            params.loanToken = USDA;
            IMorpho(MORPHO_BLUE).createMarket(params);
        }

        {
            address priceFeed = address(0x86F5CEC63eDF19209c460853B0b509C12918dB19);
            oracle = IMorphoChainlinkOracleV2Factory(MORPHO_ORACLE_FACTORY).createMorphoChainlinkOracleV2(
                address(0),
                1,
                address(priceFeed),
                address(CHAINLINK_ETH_USD_ORACLE),
                IERC20Metadata(PTEzETHDec24).decimals(),
                address(0),
                1,
                address(0),
                address(0),
                IERC20Metadata(USDA).decimals(),
                salt
            );

            uint256 price = IMorphoOracle(oracle).price();
            assertApproxEqRel(price, 3050 * 10 ** 36, 100 ** 36);
            params.collateralToken = PTEzETHDec24;
            params.lltv = LLTV_86;
            params.irm = IRM_MODEL;
            params.oracle = oracle;
            params.loanToken = USDA;
            IMorpho(MORPHO_BLUE).createMarket(params);
        }

        // {
        // // GTUSDCPrime market
        // oracle = IMorphoChainlinkOracleV2Factory(MORPHO_ORACLE_FACTORY).createMorphoChainlinkOracleV2(
        //     address(GTUSDCPRIME),
        //     1 ether,
        //     CHAINLINK_USDC_USD_ORACLE,
        //     address(0),
        //     6,
        //     address(0),
        //     1,
        //     address(0),
        //     address(0),
        //     18,
        //     salt
        // );
        // uint256 price = IMorphoOracle(oracle).price();
        // assertApproxEqRel(price, 1 * 10 ** 36, 100 ** 36);
        // params.collateralToken = GTUSDCPRIME;
        // params.lltv = LLTV_86;
        // params.irm = IRM_MODEL;
        // params.oracle = oracle;
        // params.loanToken = USDA;
        // IMorpho(MORPHO_BLUE).createMarket(params);
        // }

        vm.stopBroadcast();
    }
}
