// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import { ProxyAdmin } from "borrow-staked/external/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "borrow-staked/external/TransparentUpgradeableProxy.sol";

contract UtilsUpgradable {
    function deployUpgradeable(
        ProxyAdmin proxyAdmin,
        address implementation,
        bytes memory data
    ) public returns (address) {
        return address(new TransparentUpgradeableProxy(implementation, proxyAdmin, data));
    }
}
