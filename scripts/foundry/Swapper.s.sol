// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/swapper/Swapper.sol";
import "./Constants.s.sol";
import "utils/src/CommonUtils.sol";

contract SwapperDeploy is Script, CommonUtils {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        // TODO
        uint256 chainId = CHAIN_POLYGON;
        ICoreBorrow corebBorrow = ICoreBorrow(0xe9f183FC656656f1F17af1F2b0dF79b8fF9ad8eD);
        IAngleRouterSidechain angleRouter = IAngleRouterSidechain(0xf530b844fb797D2C6863D56a94777C3e411CEc86);
        // end TODO

        Swapper swapper = new Swapper(
            corebBorrow,
            // TODO only works for Ethereum/Arbitrum/Optimism/Polygon
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            angleRouter
        );

        console.log("Successfully deployed vanilla swapper: ", address(swapper));

        vm.stopBroadcast();
    }
}
