// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StdCheats, StdAssertions } from "forge-std/Test.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { SwapType, BaseLevSwapper, ERC4626LevSwapperMorphoGauntletUSDCPrime, Swapper } from "borrow-staked/swapper/LevSwapper/morpho/implementations/ERC4626LevSwapperMorphoGauntletUSDCPrime.sol";
import "./MainnetConstants.s.sol";
import { MarketParams } from "morpho-blue/libraries/MarketParamsLib.sol";
import { IMorpho } from "morpho-blue/interfaces/IMorpho.sol";
import { IOracle as IMorphoOracle } from "morpho-blue/interfaces/IOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IAccessControlManager } from "borrow/interfaces/IAccessControlManager.sol";
import "borrow-staked/mock/MockCoreBorrow.sol";
import "borrow-staked/mock/MockERC4626.sol";
import "borrow-staked/interfaces/external/morpho/IMorphoChainlinkOracleV2Factory.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract ERC4626SwapperLevMorphoGauntletUSDCPrime is Script, MainnetConstants, StdCheats, StdAssertions {
    MockCoreBorrow coreBorrow;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // coreBorrow = new MockCoreBorrow();
        // coreBorrow.toggleGuardian(deployer);

        ERC4626LevSwapperMorphoGauntletUSDCPrime swapperMorphoGauntletUSDCPrime = new ERC4626LevSwapperMorphoGauntletUSDCPrime(
                ICoreBorrow(CORE_BORROW),
                IUniswapV3Router(UNI_V3_ROUTER),
                ONE_INCH,
                IAngleRouterSidechain(ANGLE_ROUTER),
                IMorpho(MORPHO_BLUE)
            );

        console.log(
            "Successfully deployed swapper Morpho Gauntlet USDC prime: ",
            address(swapperMorphoGauntletUSDCPrime)
        );

        // // deploy a fake vault for the oracle liquidation
        // MarketParams memory params;
        // bytes memory emptyData;
        // IERC20(USDA).approve(MORPHO_BLUE, type(uint256).max);
        // MockERC4626 vault = new MockERC4626(
        //     IERC20Metadata(GTUSDCPRIME),
        //     IERC4626(GTUSDCPRIME).convertToAssets(1 ether)
        // );
        // // deploy Gauntlet USDC prime market
        // address oracle;
        // bytes32 salt;
        // oracle = IMorphoChainlinkOracleV2Factory(MORPHO_ORACLE_FACTORY).createMorphoChainlinkOracleV2(
        //     address(vault),
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
        // assertApproxEqRel(price, 10 ** 36, 12 * 10 ** 35);
        // params.collateralToken = GTUSDCPRIME;
        // params.lltv = LLTV_86;
        // params.irm = IRM_MODEL;
        // params.oracle = oracle;
        // params.loanToken = USDA;
        // IMorpho(MORPHO_BLUE).createMarket(params);
        // IMorpho(MORPHO_BLUE).supply(params, 35 ether, 0, deployer, emptyData);
        // IERC20(params.collateralToken).approve(MORPHO_BLUE, 100 ether);
        // IMorpho(MORPHO_BLUE).supplyCollateral(params, 50 ether, deployer, emptyData);
        // IMorpho(MORPHO_BLUE).borrow(params, 20 ether, 0, deployer, deployer);

        // // then put the position in liquidation
        // vault.setRate(IERC4626(GTUSDCPRIME).convertToAssets(1 ether) / 10);

        // price = IMorphoOracle(oracle).price();

        vm.stopBroadcast();
    }
}
