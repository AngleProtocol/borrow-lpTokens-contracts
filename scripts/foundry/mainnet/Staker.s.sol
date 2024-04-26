// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Convex3CRVStaker } from "borrow-staked/staker/curve/implementations/mainnet/pools/Convex3CRVStaker.sol";
import { StakeDAO3CRVStaker } from "borrow-staked/staker/curve/implementations/mainnet/pools/StakeDAO3CRVStaker.sol";
import "./MainnetConstants.s.sol";

contract DeployStakerMainnet is Script, MainnetConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), 0);
        vm.rememberKey(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        Convex3CRVStaker stakerConvexImplementation = new Convex3CRVStaker();
        Convex3CRVStaker stakerConvex = Convex3CRVStaker(
            deployUpgradeable(
                address(stakerConvexImplementation),
                abi.encodeWithSelector(stakerConvexImplementation.initialize.selector, CORE_BORROW)
            )
        );

        console.log(
            "Successfully deployed staker Convex 3CRV implementation at the address: ",
            address(stakerConvexImplementation)
        );
        console.log("Successfully deployed staker Convex 3CRV proxy at the address: ", address(stakerConvex));

        StakeDAO3CRVStaker stakerStakeDAOImplementation = new StakeDAO3CRVStaker();
        StakeDAO3CRVStaker stakerCurve = StakeDAO3CRVStaker(
            deployUpgradeable(
                address(stakerStakeDAOImplementation),
                abi.encodeWithSelector(stakerStakeDAOImplementation.initialize.selector, CORE_BORROW)
            )
        );

        console.log(
            "Successfully deployed staker StakeDAO 3CRV implementation at the address: ",
            address(stakerStakeDAOImplementation)
        );
        console.log("Successfully deployed staker StakeDAO 3CRV proxy at the address: ", address(stakerCurve));

        vm.stopBroadcast();
    }
}
