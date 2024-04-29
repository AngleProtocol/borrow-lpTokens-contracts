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

contract MorphoInteractMarket is Script, MainnetConstants, StdCheats, StdAssertions {
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    // depend on the market
    uint256 constant BASE_DEPOSIT_AMOUNT = BASE_DEPOSIT_ETH_AMOUNT;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        IERC20(USDA).approve(MORPHO_BLUE, 1 ether);

        MarketParams memory params;
        bytes memory emptyData;
        bytes32 salt;
        params.irm = IRM_MODEL;
        params.loanToken = USDA;

        {
            address oracle = 0x1f083a4c51E6cAa627A8Cbe7452bF3D6eb815F57;
            params.collateralToken = RE7USDT;
            params.lltv = LLTV_91;
            params.oracle = oracle;

            _getBalances(params, deployer);
            _repay(params, 0.11 ether, deployer);
            _getBalances(params, deployer);

            // IMorpho(MORPHO_BLUE).supply(params, 35 ether, 0, deployer, emptyData);
            // IMorpho(MORPHO_BLUE).withdraw(params, 999 ether, 0, deployer, deployer);
            // IERC20(params.collateralToken).approve(MORPHO_BLUE, BASE_DEPOSIT_AMOUNT);
            // IMorpho(MORPHO_BLUE).supplyCollateral(params, BASE_DEPOSIT_AMOUNT, deployer, emptyData);
            // IMorpho(MORPHO_BLUE).borrow(params, 20 ether, 0, deployer, deployer);
            // IMorpho(MORPHO_BLUE).repay(params, 50 ether, 0, deployer, emptyData);
        }

        {
            address oracle = 0x76052A2A28fDCB8124f4686C63C68355b142de3B;
            params.collateralToken = RE7ETH;
            params.lltv = LLTV_86;
            params.oracle = oracle;

            _getBalances(params, deployer);
            _repay(params, 0.11 ether, deployer);
            _getBalances(params, deployer);
        }

        {
            address oracle = 0x3B8c4A340336941524DE276FF730b3Be71157B55;
            params.collateralToken = GTUSDCPRIME;
            params.lltv = LLTV_86;
            params.oracle = oracle;

            _getBalances(params, deployer);
            _repay(params, 0.11 ether, deployer);
            _getBalances(params, deployer);
        }

        {
            address oracle = 0xe4CCAA1849e9058f77f555C0FCcA4925Efd37d8E;
            params.collateralToken = GTETHPRIME;
            params.lltv = LLTV_77;
            params.oracle = oracle;

            _getBalances(params, deployer);
            _repay(params, 0.11 ether, deployer);
            _getBalances(params, deployer);
        }

        // {
        //     address oracle = 0x5441731eED05A8208e795086a5dF41416DD34104;
        //     params.collateralToken = PTWeETH;
        //     params.lltv = LLTV_86;
        //     params.oracle = oracle;

        //     _getBalances(params, deployer);
        //     _repay(params, 50 ether, deployer);
        // }

        // Check variables
        uint256 balance = IMorpho(MORPHO_BLUE).expectedSupplyAssets(params, deployer);

        // To force liquidation update some storage

        // (, int256 pricePT, , , ) = MorphoFeedPTweETH(priceFeed).latestRoundData();

        // PT manipulation
        // MorphoFeedPTweETH(priceFeed).setMaxImpliedRate(1000 ether);
        // ERC4626
        // vault.setRate(IERC4626(GTUSDCPRIME).convertToAssets(1 ether) / 10);

        // (, pricePT, , , ) = MorphoFeedPTweETH(priceFeed).latestRoundData();

        vm.stopBroadcast();
    }

    function _repay(MarketParams memory params, uint256 amount, address borrower) internal {
        bytes memory emptyData;
        IMorpho(MORPHO_BLUE).repay(params, amount, 0, borrower, emptyData);
    }

    function _getBalances(MarketParams memory params, address account) internal view {
        uint256 balance = IMorpho(MORPHO_BLUE).expectedBorrowAssets(params, account);
        console.log("balance: ", balance);
        uint256 totalBorrow = IMorpho(MORPHO_BLUE).expectedTotalBorrowAssets(params);
        console.log("totalBorrow: ", totalBorrow);
        uint256 borrowRate = IIrm(params.irm).borrowRateView(params, IMorpho(MORPHO_BLUE).market(params.id()));
        console.log("borrowRate: ", borrowRate * 365 * 24 * 60 * 60);
    }
}
