// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { ConvexLevSwapper3CRV } from "../../../contracts/swapper/LevSwapper/curve/implementations/mainnet/convex/ConvexLevSwapper3CRV.sol";
import { StakeDAOLevSwapper3CRV } from "../../../contracts/swapper/LevSwapper/curve/implementations/mainnet/stakeDAO/StakeDAOLevSwapper3CRV.sol";
import "./MainnetConstants.s.sol";

contract DeploySwapperMainnet is Script, MainnetConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), 0);
        vm.startBroadcast(deployerPrivateKey);

        ConvexLevSwapper3CRV swapperConvex = new ConvexLevSwapper3CRV(
            ICoreBorrow(CORE_BORROW),
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(ANGLE_ROUTER)
        );

        console.log("Successfully deployed swapper Convex 3CRV at the address: ", address(swapperConvex));

        StakeDAOLevSwapper3CRV swapperStakeDAO = new StakeDAOLevSwapper3CRV(
            ICoreBorrow(CORE_BORROW),
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(ANGLE_ROUTER)
        );

        console.log("Successfully deployed swapper StakeDAO 3CRV at the address: ", address(swapperStakeDAO));

        vm.stopBroadcast();
    }
}
