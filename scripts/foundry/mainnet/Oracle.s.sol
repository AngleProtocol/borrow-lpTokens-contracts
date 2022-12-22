// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "borrow/interfaces/IOracle.sol";
import { OracleFRAXBPEURChainlink } from "../../../contracts/oracle/implementations/mainnet/OracleFRAXBPEURChainlink.sol";
import "./MainnetConstants.s.sol";

contract DeployOracleMainnet is Script, MainnetConstants {
    uint32 public constant STALE_PERIOD = 3600 * 24;

    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), 0);
        vm.startBroadcast(deployerPrivateKey);

        IOracle oracle = new OracleFRAXBPEURChainlink(STALE_PERIOD, address(AGEUR_TREASURY));

        console.log("Successfully deployed Oracle Curve FRAXBP at the address: ", address(oracle));

        vm.stopBroadcast();
    }
}
