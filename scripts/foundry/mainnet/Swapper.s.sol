// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { ConvexLevSwapperLUSDv3CRV } from "../../../contracts/swapper/LevSwapper/curve/implementations/mainnet/convex/ConvexLevSwapperLUSDv3CRV.sol";
import { StakeDAOLevSwapperLUSDv3CRV } from "../../../contracts/swapper/LevSwapper/curve/implementations/mainnet/stakeDAO/StakeDAOLevSwapperLUSDv3CRV.sol";
import "./MainnetConstants.s.sol";

contract DeploySwapperMainnet is Script, MainnetConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), 0);
        vm.startBroadcast(deployerPrivateKey);

        ConvexLevSwapperLUSDv3CRV swapperConvex = new ConvexLevSwapperLUSDv3CRV(
            ICoreBorrow(CORE_BORROW),
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(ANGLE_ROUTER)
        );

        console.log("Successfully deployed swapper Convex LUSD3CRV at the address: ", address(swapperConvex));

        StakeDAOLevSwapperLUSDv3CRV swapperStakeDAO = new StakeDAOLevSwapperLUSDv3CRV(
            ICoreBorrow(CORE_BORROW),
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(ANGLE_ROUTER)
        );

        console.log("Successfully deployed swapper StakeDAO LUSD3CRV at the address: ", address(swapperStakeDAO));

        vm.stopBroadcast();
    }
}
