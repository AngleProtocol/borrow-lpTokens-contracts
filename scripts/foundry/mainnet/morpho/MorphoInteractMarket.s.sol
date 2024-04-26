// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StdCheats, StdAssertions } from "forge-std/Test.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { SwapType, BaseLevSwapper, PendleLevSwapperMorphoWeETH, PendleLevSwapperMorpho, Swapper } from "borrow-staked/swapper/LevSwapper/morpho/implementations/PendleLevSwapperMorphoWeETH.sol";
import { MarketParams } from "morpho-blue/libraries/MarketParamsLib.sol";
import { IIrm } from "morpho-blue/interfaces/IIRM.sol";
import { IMorpho } from "morpho-blue/interfaces/IMorpho.sol";
import { IOracle as IMorphoOracle } from "morpho-blue/interfaces/IOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { MorphoFeedPTweETH } from "borrow/oracle/morpho/mainnet/MorphoFeedPTweETH.sol";
import { IAccessControlManager } from "borrow/interfaces/IAccessControlManager.sol";
import "borrow-staked/interfaces/external/morpho/IMorphoChainlinkOracleV2Factory.sol";
import { MorphoBalancesLib } from "morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import { MarketParamsLib } from "morpho-blue/libraries/MarketParamsLib.sol";
import "../MainnetConstants.s.sol";

contract SwapperSupply is Script, MainnetConstants, StdCheats, StdAssertions {
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    // depend on the market
    uint256 constant BASE_DEPOSIT_AMOUNT = BASE_DEPOSIT_ETH_AMOUNT;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        IERC20(USDA).approve(MORPHO_BLUE, type(uint256).max);

        MarketParams memory params;
        bytes memory emptyData;
        bytes32 salt;
        address oracle = 0x1f083a4c51E6cAa627A8Cbe7452bF3D6eb815F57;
        uint256 price = IMorphoOracle(oracle).price();
        params.collateralToken = RE7USDT;
        params.lltv = LLTV_91;
        params.irm = IRM_MODEL;
        params.oracle = oracle;
        params.loanToken = USDA;

        uint256 balance = IMorpho(MORPHO_BLUE).expectedSupplyAssets(params, deployer);
        uint256 totalBorrow = IMorpho(MORPHO_BLUE).expectedTotalBorrowAssets(params);
        uint256 borrowRate = IIrm(params.irm).borrowRateView(params, IMorpho(MORPHO_BLUE).market(params.id()));
        console.log("borrowRate: ", borrowRate * 365 * 24 * 60 * 60);

        // IMorpho(MORPHO_BLUE).supply(params, 35 ether, 0, deployer, emptyData);
        // IMorpho(MORPHO_BLUE).withdraw(params, 999 ether, 0, deployer, deployer);
        // IERC20(params.collateralToken).approve(MORPHO_BLUE, BASE_DEPOSIT_AMOUNT);
        // IMorpho(MORPHO_BLUE).supplyCollateral(params, BASE_DEPOSIT_AMOUNT, deployer, emptyData);
        // IMorpho(MORPHO_BLUE).borrow(params, 20 ether, 0, deployer, deployer);

        IMorpho(MORPHO_BLUE).supply(params, 35 ether, 0, deployer, emptyData);
        IERC20(params.collateralToken).approve(MORPHO_BLUE, 100 ether);
        IMorpho(MORPHO_BLUE).supplyCollateral(params, 50 ether, deployer, emptyData);
        IMorpho(MORPHO_BLUE).borrow(params, 20 ether, 0, deployer, deployer);
        // Check variables
        balance = IMorpho(MORPHO_BLUE).expectedSupplyAssets(params, deployer);

        // To force liquidation update some storage

        // (, int256 pricePT, , , ) = MorphoFeedPTweETH(priceFeed).latestRoundData();

        // PT manipulation
        // MorphoFeedPTweETH(priceFeed).setMaxImpliedRate(1000 ether);
        // ERC4626
        // vault.setRate(IERC4626(GTUSDCPRIME).convertToAssets(1 ether) / 10);

        // (, pricePT, , , ) = MorphoFeedPTweETH(priceFeed).latestRoundData();

        vm.stopBroadcast();
    }
}
