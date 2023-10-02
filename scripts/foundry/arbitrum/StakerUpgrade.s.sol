// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Convex2PoolStaker } from "../../../contracts/staker/curve/implementations/arbitrum/pools/Convex2PoolStaker.sol";
import { StakeDAO2PoolStaker } from "../../../contracts/staker/curve/implementations/arbitrum/pools/StakeDAO2PoolStaker.sol";
import "./ArbitrumConstants.s.sol";
import "../../../contracts/external/TransparentUpgradeableProxy.sol";

contract UpgradeStakerArbitrum is Script, ArbitrumConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_ARBITRUM"), 0);
        vm.rememberKey(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        StakeDAO2PoolStaker stakerStakeDAOImplementation = new StakeDAO2PoolStaker();

        console.log(
            "Successfully deployed staker StakeDAO 2Pool implementation at the address: ",
            address(stakerStakeDAOImplementation)
        );
        vm.stopBroadcast();

        vm.startBroadcast(GOVERNOR);
        TransparentUpgradeableProxy stakerCurve = TransparentUpgradeableProxy(
            payable(address(0xc8711B1206cD3e89799Ec32973f583e696Cb553C))
        );

        ProxyAdmin(PROXY_ADMIN).upgrade(stakerCurve, address(stakerStakeDAOImplementation));
        console.log("Successfully upgraded staker StakeDAO 2Pool proxy at the address: ", address(stakerCurve));

        vm.stopBroadcast();
    }
}
