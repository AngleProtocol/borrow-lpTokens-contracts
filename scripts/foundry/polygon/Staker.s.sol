// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { MockCurveTokenStakerAaveBP } from "borrow-staked/staker/curve/implementations/polygon/pools/polygonTest/MockCurveTokenStakerAaveBP.sol";
import "./PolygonConstants.s.sol";
import "../UtilsUpgradable.s.sol";

contract DeployStaker is Script, PolygonConstants, UtilsUpgradable {
    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_POLYGON"), 2);
        vm.rememberKey(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        MockCurveTokenStakerAaveBP stakerImplementation = new MockCurveTokenStakerAaveBP();
        MockCurveTokenStakerAaveBP staker = MockCurveTokenStakerAaveBP(
            deployUpgradeable(
                PROXY_ADMIN,
                address(stakerImplementation),
                abi.encodeWithSelector(stakerImplementation.initialize.selector, CORE_BORROW)
            )
        );

        console.log(
            "Successfully deployed staker Curve AaveBP implementation at the address: ",
            address(stakerImplementation)
        );
        console.log("Successfully deployed staker Curve AaveBP proxy at the address: ", address(staker));

        vm.stopBroadcast();
    }
}
