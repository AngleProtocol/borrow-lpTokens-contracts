// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StdCheats, StdAssertions } from "forge-std/Test.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "../BaseConstants.s.sol";
import { MarketParams } from "morpho-blue/libraries/MarketParamsLib.sol";
import { IMorpho } from "morpho-blue/interfaces/IMorpho.sol";
import { IOracle as IMorphoOracle } from "morpho-blue/interfaces/IOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "borrow-staked/interfaces/external/morpho/IMorphoChainlinkOracleV2Factory.sol";
import { MorphoBalancesLib } from "morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import { MarketParamsLib } from "morpho-blue/libraries/MarketParamsLib.sol";
import { CommonUtils } from "utils/src/CommonUtils.sol";
import "utils/src/Constants.sol";

contract MorphoDeployBaseMarket is Script, CommonUtils, BaseConstants, StdCheats, StdAssertions {
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    ICoreBorrow coreBorrow;
    address USDA;
    address deployer;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("KEEPER_PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Can be changed to a new MockCoreBorrow if you want to manipulate the price
        coreBorrow = ICoreBorrow(_chainToContract(CHAIN_BASE, ContractType.CoreBorrow));
        USDA = _chainToContract(CHAIN_BASE, ContractType.AgUSD);

        MarketParams memory params;
        bytes memory emptyData;
        address oracle;
        bytes32 salt;

        {
            address collateral = cbETH;
            oracle = IMorphoChainlinkOracleV2Factory(MORPHO_ORACLE_FACTORY).createMorphoChainlinkOracleV2(
                address(0),
                1,
                address(CBETH_ETH_ORACLE),
                address(ETH_USD_ORACLE),
                IERC20Metadata(collateral).decimals(),
                address(0),
                1,
                address(0),
                address(0),
                IERC20Metadata(USDA).decimals(),
                salt
            );

            uint256 price = IMorphoOracle(oracle).price();
            // Because with the max implied rate there is a discount compared to the on chain price (3250)
            assertApproxEqAbs(price, 3800 * 10 ** 36, 50 * 10 ** 36);
            params.collateralToken = collateral;
            params.lltv = LLTV_86;
            params.irm = IRM_MODEL;
            params.oracle = oracle;
            params.loanToken = USDA;
            IMorpho(MORPHO_BLUE).createMarket(params);

            initMarket(params, BASE_DEPOSIT_ETH_AMOUNT);
        }

        // {
        //     address collateral = weETH;
        //     oracle = IMorphoChainlinkOracleV2Factory(MORPHO_ORACLE_FACTORY).createMorphoChainlinkOracleV2(
        //         address(0),
        //         1,
        //         address(WEETH_ETH_ORACLE),
        //         address(ETH_USD_ORACLE),
        //         IERC20Metadata(collateral).decimals(),
        //         address(0),
        //         1,
        //         address(0),
        //         address(0),
        //         IERC20Metadata(USDA).decimals(),
        //         salt
        //     );

        //     uint256 price = IMorphoOracle(oracle).price();
        //     // Because with the max implied rate there is a discount compared to the on chain price (3250)
        //     assertApproxEqAbs(price, 3670 * 10 ** 36, 50 * 10 ** 36);
        //     params.collateralToken = collateral;
        //     params.lltv = LLTV_86;
        //     params.irm = IRM_MODEL;
        //     params.oracle = oracle;
        //     params.loanToken = USDA;
        //     IMorpho(MORPHO_BLUE).createMarket(params);

        //     initMarket(params, BASE_DEPOSIT_ETH_AMOUNT);
        // }

        {
            address collateral = ezETH;
            // oracle = IMorphoChainlinkOracleV2Factory(MORPHO_ORACLE_FACTORY).createMorphoChainlinkOracleV2(
            //     address(0),
            //     1,
            //     address(EZETH_ETH_ORACLE),
            //     address(ETH_USD_ORACLE),
            //     IERC20Metadata(collateral).decimals(),
            //     address(0),
            //     1,
            //     address(0),
            //     address(0),
            //     IERC20Metadata(USDA).decimals(),
            //     salt
            // );
            // Oracle already deployed by someone else
            oracle = 0x4B5086653F9db675df31a618971e0EC26f6f081F;

            uint256 price = IMorphoOracle(oracle).price();
            // Because with the max implied rate there is a discount compared to the on chain price (3250)
            assertApproxEqAbs(price, 3540 * 10 ** 36, 50 ** 36);
            params.collateralToken = collateral;
            params.lltv = LLTV_86;
            params.irm = IRM_MODEL;
            params.oracle = oracle;
            params.loanToken = USDA;
            IMorpho(MORPHO_BLUE).createMarket(params);

            initMarket(params, BASE_DEPOSIT_ETH_AMOUNT);
        }

        {
            address collateral = wstETH;
            // oracle = IMorphoChainlinkOracleV2Factory(MORPHO_ORACLE_FACTORY).createMorphoChainlinkOracleV2(
            //     address(0),
            //     1,
            //     address(WSTETH_ETH_ORACLE),
            //     address(ETH_USD_ORACLE),
            //     IERC20Metadata(collateral).decimals(),
            //     address(0),
            //     1,
            //     address(0),
            //     address(0),
            //     IERC20Metadata(USDA).decimals(),
            //     salt
            // );
            // Oracle already deployed by someone else
            oracle = 0x040ba460Ed355833a0693348421C7f1fd831D0c7;

            uint256 price = IMorphoOracle(oracle).price();
            // Because with the max implied rate there is a discount compared to the on chain price (3250)
            assertApproxEqAbs(price, 4100 * 10 ** 36, 50 * 10 ** 36);
            params.collateralToken = collateral;
            params.lltv = LLTV_86;
            params.irm = IRM_MODEL;
            params.oracle = oracle;
            params.loanToken = USDA;
            IMorpho(MORPHO_BLUE).createMarket(params);

            initMarket(params, BASE_DEPOSIT_ETH_AMOUNT);
        }

        vm.stopBroadcast();
    }

    function initMarket(MarketParams memory params, uint256 amountCollateral) internal {
        bytes memory emptyData;
        IERC20(params.loanToken).approve(MORPHO_BLUE, BASE_DEPOSIT_USD_AMOUNT);
        IMorpho(MORPHO_BLUE).supply(params, BASE_DEPOSIT_USD_AMOUNT, 0, deployer, emptyData);
        IERC20(params.collateralToken).approve(MORPHO_BLUE, amountCollateral);
        IMorpho(MORPHO_BLUE).supplyCollateral(params, amountCollateral, deployer, emptyData);
        IMorpho(MORPHO_BLUE).borrow(params, (BASE_DEPOSIT_USD_AMOUNT * 9) / 10, 0, deployer, deployer);
    }
}
