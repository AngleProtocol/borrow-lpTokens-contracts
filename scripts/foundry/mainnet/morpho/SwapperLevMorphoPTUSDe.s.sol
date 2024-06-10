// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StdCheats, StdAssertions } from "forge-std/Test.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { PendleLevSwapperMorphoUSDe } from "borrow-staked/swapper/LevSwapper/morpho/implementations/PendleLevSwapperMorphoUSDe.sol";
import "../MainnetConstants.s.sol";
import { IMorpho } from "morpho-blue/interfaces/IMorpho.sol";
import "borrow/interfaces/ICoreBorrow.sol";

contract SwapperLevMorphoPTUSDe is Script, MainnetConstants, StdCheats, StdAssertions {
    ICoreBorrow coreBorrow;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        coreBorrow = ICoreBorrow(CORE_BORROW);
        // If you want to modify one of the entry in the price feed
        // coreBorrow = new MockCoreBorrow();
        // coreBorrow.toggleGuardian(deployer);

        PendleLevSwapperMorphoUSDe swapperMorphoPTUSDe = new PendleLevSwapperMorphoUSDe(
            coreBorrow,
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(ANGLE_ROUTER),
            IMorpho(MORPHO_BLUE)
        );
        console.log("Successfully deployed swapper Morpho PT-USDe Pendle: ", address(swapperMorphoPTUSDe));

        vm.stopBroadcast();
    }
}
