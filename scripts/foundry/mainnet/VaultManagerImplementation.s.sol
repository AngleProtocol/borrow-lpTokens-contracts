// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { VaultManagerListing } from "borrow-staked/vaultManager/VaultManagerListing.sol";
import "./MainnetConstants.s.sol";

contract DeployVaultManagerImplementationMainnet is Script, MainnetConstants {
    VaultManagerListing public vaultManagerImplementation;

    function run() external {
        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), 0);
        vm.startBroadcast(deployerPrivateKey);

        vaultManagerImplementation = new VaultManagerListing();

        console.log(
            "Successfully deployed vaultManagerImplementation at the address: ",
            address(vaultManagerImplementation)
        );

        vm.stopBroadcast();
    }
}
