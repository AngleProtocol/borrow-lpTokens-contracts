// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { ConvexLevSwapper2Pool } from "../../../contracts/swapper/LevSwapper/curve/implementations/arbitrum/convex/ConvexLevSwapper2Pool.sol";
import { StakeDAOLevSwapper2Pool } from "../../../contracts/swapper/LevSwapper/curve/implementations/arbitrum/stakeDAO/StakeDAOLevSwapper2Pool.sol";
import "./ArbitrumConstants.s.sol";

contract DeploySwapperArbitrum is Script, ArbitrumConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_ARBITRUM"), 0);

        vm.startBroadcast(deployerPrivateKey);

        ConvexLevSwapper2Pool swapperConvex = new ConvexLevSwapper2Pool(
            ICoreBorrow(CORE_BORROW),
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(ANGLE_ROUTER)
        );

        console.log("Successfully deployed swapper Convex 2Pool at the address: ", address(swapperConvex));

        StakeDAOLevSwapper2Pool swapperStakeDAO = new StakeDAOLevSwapper2Pool(
            ICoreBorrow(CORE_BORROW),
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(ANGLE_ROUTER)
        );

        console.log("Successfully deployed swapper StakeDAO 2Pool at the address: ", address(swapperStakeDAO));

        vm.stopBroadcast();
    }
}
