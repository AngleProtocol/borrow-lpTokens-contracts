// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { MockCurveLevSwapperAaveBP } from "borrow-staked/swapper/LevSwapper/curve/implementations/polygon/polygonTest/MockCurveLevSwapperAaveBP.sol";
import "./PolygonConstants.s.sol";

contract DeploySwapper is Script, PolygonConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_POLYGON"), 2);
        vm.startBroadcast(deployerPrivateKey);

        MockCurveLevSwapperAaveBP swapper = new MockCurveLevSwapperAaveBP(
            ICoreBorrow(CORE_BORROW),
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(ANGLE_ROUTER)
        );

        console.log("Successfully deployed swapper Curve Aave BP at the address: ", address(swapper));

        vm.stopBroadcast();
    }
}
