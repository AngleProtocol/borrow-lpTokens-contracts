// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { SwapType, BaseLevSwapper, PendleLevSwapperMorphoWeETH, PendleLevSwapperMorpho, Swapper } from "contracts/swapper/LevSwapper/morpho/implementations/PendleLevSwapperMorphoWeETH.sol";
import "./MainnetConstants.s.sol";
import { IMorphoBase } from "morpho-blue/interfaces/IMorpho.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SwapperLevMorpho is Script, MainnetConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        PendleLevSwapperMorphoWeETH swapperMorphoPTWeETH = new PendleLevSwapperMorphoWeETH(
            ICoreBorrow(CORE_BORROW),
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(ANGLE_ROUTER),
            IMorphoBase(MORPHO_BLUE)
        );

        console.log("Successfully deployed swapper Morpho PT-weETH Pendle: ", address(swapperMorphoPTWeETH));

        // Set oracles to have liquidable positions
        // vm.mockCall(
        //     address(0x986b5E1e1755e3C2440e960477f25201B0a8bbD4),
        //     abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
        //     abi.encode(0, 0.001 ether, 0, 0, 0)
        // );

        vm.stopBroadcast();
    }
}
