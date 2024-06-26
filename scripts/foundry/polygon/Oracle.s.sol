// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "borrow/interfaces/IOracle.sol";
import { OracleAaveUSDBPEUR } from "borrow-staked/oracle/implementations/polygon/OracleAaveUSDBPEUR.sol";
import "./PolygonConstants.s.sol";

contract DeployOracle is Script, PolygonConstants {
    uint32 public constant STALE_PERIOD = 3600 * 48;

    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_POLYGON"), 2);
        vm.startBroadcast(deployerPrivateKey);

        IOracle oracle = new OracleAaveUSDBPEUR(STALE_PERIOD, address(AGEUR_TREASURY));

        console.log("Successfully deployed Oracle Curve AaveBP at the address: ", address(oracle));

        vm.stopBroadcast();
    }
}
