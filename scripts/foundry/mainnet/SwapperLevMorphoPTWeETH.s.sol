// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StdCheats, StdAssertions } from "forge-std/Test.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { SwapType, BaseLevSwapper, PendleLevSwapperMorphoWeETH, PendleLevSwapperMorpho, Swapper } from "borrow-staked/swapper/LevSwapper/morpho/implementations/PendleLevSwapperMorphoWeETH.sol";
import "./MainnetConstants.s.sol";
import { MarketParams } from "morpho-blue/libraries/MarketParamsLib.sol";
import { IMorpho } from "morpho-blue/interfaces/IMorpho.sol";
import { IOracle as IMorphoOracle } from "morpho-blue/interfaces/IOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { MorphoFeedPTweETH } from "borrow/oracle/morpho/mainnet/MorphoFeedPTweETH.sol";
import { IAccessControlManager } from "borrow/interfaces/IAccessControlManager.sol";
import "borrow-staked/mock/MockCoreBorrow.sol";
import "borrow-staked/interfaces/external/morpho/IMorphoChainlinkOracleV2Factory.sol";

contract SwapperLevMorphoPTWeETH is Script, MainnetConstants, StdCheats, StdAssertions {
    MockCoreBorrow coreBorrow;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // coreBorrow = new MockCoreBorrow();
        // coreBorrow.toggleGuardian(deployer);

        PendleLevSwapperMorphoWeETH swapperMorphoPTWeETH = new PendleLevSwapperMorphoWeETH(
            ICoreBorrow(CORE_BORROW),
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(ANGLE_ROUTER),
            IMorpho(MORPHO_BLUE)
        );
        console.log("Successfully deployed swapper Morpho PT-weETH Pendle: ", address(swapperMorphoPTWeETH));

        // // deploy PT market
        // MarketParams memory params;
        // bytes memory emptyData;
        // IERC20(USDA).approve(MORPHO_BLUE, type(uint256).max);
        // address oracle;
        // bytes32 salt;
        // address priceFeed = address(
        //     new MorphoFeedPTweETH(IAccessControlManager(address(coreBorrow)), _MAX_IMPLIED_RATE, _TWAP_DURATION)
        // );
        // oracle = IMorphoChainlinkOracleV2Factory(MORPHO_ORACLE_FACTORY).createMorphoChainlinkOracleV2(
        //     address(0),
        //     1,
        //     address(priceFeed),
        //     address(WEETH_USD_ORACLE),
        //     IERC20Metadata(PTWeETH).decimals(),
        //     address(0),
        //     1,
        //     address(0),
        //     address(0),
        //     IERC20Metadata(USDA).decimals(),
        //     salt
        // );
        // uint256 price = IMorphoOracle(oracle).price();
        // assertApproxEqRel(price, 3350 * 10 ** 36, 100 ** 36);
        // params.collateralToken = PTWeETH;
        // params.lltv = LLTV_86;
        // params.irm = IRM_MODEL;
        // params.oracle = oracle;
        // params.loanToken = USDA;
        // IMorpho(MORPHO_BLUE).createMarket(params);
        // IMorpho(MORPHO_BLUE).supply(params, 35 ether, 0, deployer, emptyData);
        // IERC20(params.collateralToken).approve(MORPHO_BLUE, BASE_DEPOSIT_ETH_AMOUNT);
        // IMorpho(MORPHO_BLUE).supplyCollateral(params, BASE_DEPOSIT_ETH_AMOUNT, deployer, emptyData);
        // IMorpho(MORPHO_BLUE).borrow(params, 20 ether, 0, deployer, deployer);
        // (, int256 pricePT, , , ) = MorphoFeedPTweETH(priceFeed).latestRoundData();
        // MorphoFeedPTweETH(priceFeed).setMaxImpliedRate(1000 ether);
        // (, pricePT, , , ) = MorphoFeedPTweETH(priceFeed).latestRoundData();
        // vm.stopBroadcast();
    }
}
