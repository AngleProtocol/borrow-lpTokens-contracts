// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "borrow/interfaces/IOracle.sol";
import { Oracle2PoolEURChainlinkArbitrum } from "borrow-staked/oracle/implementations/arbitrum/Oracle2PoolEURChainlinkArbitrum.sol";
import "./ArbitrumConstants.s.sol";

contract DeployOracleArbitrum is Script, ArbitrumConstants {
    uint32 public constant STALE_PERIOD = 3600 * 48;

    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_ARBITRUM"), 0);
        vm.startBroadcast(deployerPrivateKey);

        IOracle oracle = new Oracle2PoolEURChainlinkArbitrum(STALE_PERIOD, address(AGEUR_TREASURY));

        console.log("Successfully deployed Oracle Curve 2Pool at the address: ", address(oracle));

        vm.stopBroadcast();
    }
}
