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

        uint256 chainId = CHAIN_ARBITRUM;

        Swapper swapper = new Swapper(
            ICoreBorrow(_chainToContract(chainId, ContractType.CoreBorrow)),
            // TODO only works for Ethereum/Arbitrum/Optimism/Polygon
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(_chainToContract(chainId, ContractType.AngleRouter))
        );

        console.log("Successfully deployed vanilla swapper: ", address(swapper));

        vm.stopBroadcast();
    }
}
