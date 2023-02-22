// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "borrow/interfaces/IOracle.sol";
import { OracleLUSD3CRVEURChainlink } from "../../../contracts/oracle/implementations/mainnet/OracleLUSD3CRVEURChainlink.sol";
import "./MainnetConstants.s.sol";

contract DeployOracleMainnet is Script, MainnetConstants {
    uint32 public constant STALE_PERIOD = 3600 * 48;

    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), 0);
        vm.startBroadcast(deployerPrivateKey);

        IOracle oracle = new OracleLUSD3CRVEURChainlink(STALE_PERIOD, address(AGEUR_TREASURY));

        console.log("Successfully deployed Oracle Curve LUSD3CRV at the address: ", address(oracle));

        vm.stopBroadcast();
    }
}
