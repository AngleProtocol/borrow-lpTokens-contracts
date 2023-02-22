// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ConvexLUSDv3CRVStaker } from "../../../contracts/staker/curve/implementations/mainnet/pools/ConvexLUSDv3CRVStaker.sol";
import { StakeDAOLUSDv3CRVStaker } from "../../../contracts/staker/curve/implementations/mainnet/pools/StakeDAOLUSDv3CRVStaker.sol";
import "./MainnetConstants.s.sol";

contract DeployStakerMainnet is Script, MainnetConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), 0);
        vm.rememberKey(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        ConvexLUSDv3CRVStaker stakerConvexImplementation = new ConvexLUSDv3CRVStaker();
        ConvexLUSDv3CRVStaker stakerConvex = ConvexLUSDv3CRVStaker(
            deployUpgradeable(
                address(stakerConvexImplementation),
                abi.encodeWithSelector(stakerConvexImplementation.initialize.selector, CORE_BORROW)
            )
        );

        console.log(
            "Successfully deployed staker Convex LUSD3CRV implementation at the address: ",
            address(stakerConvexImplementation)
        );
        console.log("Successfully deployed staker Convex LUSD3CRV proxy at the address: ", address(stakerConvex));

        StakeDAOLUSDv3CRVStaker stakerStakeDAOImplementation = new StakeDAOLUSDv3CRVStaker();
        StakeDAOLUSDv3CRVStaker stakerCurve = StakeDAOLUSDv3CRVStaker(
            deployUpgradeable(
                address(stakerStakeDAOImplementation),
                abi.encodeWithSelector(stakerStakeDAOImplementation.initialize.selector, CORE_BORROW)
            )
        );

        console.log(
            "Successfully deployed staker StakeDAO LUSD3CRV implementation at the address: ",
            address(stakerStakeDAOImplementation)
        );
        console.log("Successfully deployed staker StakeDAO LUSD3CRV proxy at the address: ", address(stakerCurve));

        vm.stopBroadcast();
    }
}
