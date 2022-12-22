// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ConvexFRAXBPStaker } from "../../../contracts/staker/curve/implementations/mainnet/ConvexFRAXBPStaker.sol";
import { StakeDAOFRAXBPStaker } from "../../../contracts/staker/curve/implementations/mainnet/StakeDAOFRAXBPStaker.sol";
import "./MainnetConstants.s.sol";

contract DeployStakerMainnet is Script, MainnetConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), 0);
        vm.rememberKey(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        ConvexFRAXBPStaker stakerConvexImplementation = new ConvexFRAXBPStaker();
        ConvexFRAXBPStaker stakerConvex = ConvexFRAXBPStaker(
            deployUpgradeable(
                address(stakerConvexImplementation),
                abi.encodeWithSelector(stakerConvexImplementation.initialize.selector, CORE_BORROW)
            )
        );

        console.log(
            "Successfully deployed staker Convex FRAXBP implementation at the address: ",
            address(stakerConvexImplementation)
        );
        console.log("Successfully deployed staker Convex FRAXBP proxy at the address: ", address(stakerConvex));

        StakeDAOFRAXBPStaker stakerStakeDAOImplementation = new StakeDAOFRAXBPStaker();
        StakeDAOFRAXBPStaker stakerCurve = StakeDAOFRAXBPStaker(
            deployUpgradeable(
                address(stakerStakeDAOImplementation),
                abi.encodeWithSelector(stakerStakeDAOImplementation.initialize.selector, CORE_BORROW)
            )
        );

        console.log(
            "Successfully deployed staker StakeDAO FRAXBP implementation at the address: ",
            address(stakerStakeDAOImplementation)
        );
        console.log("Successfully deployed staker StakeDAO FRAXBP proxy at the address: ", address(stakerCurve));

        vm.stopBroadcast();
    }
}
