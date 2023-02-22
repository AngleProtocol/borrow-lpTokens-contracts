// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Convex2PoolStaker } from "../../../contracts/staker/curve/implementations/arbitrum/pools/Convex2PoolStaker.sol";
import { StakeDAO2PoolStaker } from "../../../contracts/staker/curve/implementations/arbitrum/pools/StakeDAO2PoolStaker.sol";
import "./ArbitrumConstants.s.sol";

contract DeployStakerArbitrum is Script, ArbitrumConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_ARBITRUM"), 0);
        vm.rememberKey(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        Convex2PoolStaker stakerConvexImplementation = new Convex2PoolStaker();
        Convex2PoolStaker stakerConvex = Convex2PoolStaker(
            deployUpgradeable(
                address(stakerConvexImplementation),
                abi.encodeWithSelector(stakerConvexImplementation.initialize.selector, CORE_BORROW)
            )
        );

        console.log(
            "Successfully deployed staker Convex 2Pool implementation at the address: ",
            address(stakerConvexImplementation)
        );
        console.log("Successfully deployed staker Convex 2Pool proxy at the address: ", address(stakerConvex));

        StakeDAO2PoolStaker stakerStakeDAOImplementation = new StakeDAO2PoolStaker();
        StakeDAO2PoolStaker stakerCurve = StakeDAO2PoolStaker(
            deployUpgradeable(
                address(stakerStakeDAOImplementation),
                abi.encodeWithSelector(stakerStakeDAOImplementation.initialize.selector, CORE_BORROW)
            )
        );

        console.log(
            "Successfully deployed staker StakeDAO 2Pool implementation at the address: ",
            address(stakerStakeDAOImplementation)
        );
        console.log("Successfully deployed staker StakeDAO 2Pool proxy at the address: ", address(stakerCurve));

        vm.stopBroadcast();
    }
}
