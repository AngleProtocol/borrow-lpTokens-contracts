// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import { ProxyAdmin } from "borrow-staked/external/ProxyAdmin.sol";
import { TransparentUpgradeableProxy } from "borrow-staked/external/TransparentUpgradeableProxy.sol";

contract ArbitrumConstants {
    address public constant GOVERNOR = 0xAA2DaCCAb539649D1839772C625108674154df0B;
    address public constant GUARDIAN = 0x55F01DDaE74b60e3c255BD2f619FEbdFce560a9C;
    address public constant PROXY_ADMIN = 0x9a5b060Bd7b8f86c4C0D720a17367729670AfB19;
    address public constant PROXY_ADMIN_GUARDIAN = 0xf2eDa0829E8A9CF53EBCB8AFCBb558D2eABCEF64;
    address public constant CORE_BORROW = 0x31429d1856aD1377A8A0079410B297e1a9e214c2;

    address public constant ANGLE_ROUTER = 0x9A33e690AA78A4c346e72f7A5e16e5d7278BE835;
    address public constant ONE_INCH = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address public constant UNI_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    // AGEUR Mainnet treasury
    address public constant AGEUR_TREASURY = 0x0D710512E100C171139D2Cf5708f22C680eccF52;
    address public constant AGEUR = 0xFA5Ed56A203466CbBC2430a43c66b9D8723528E7;

    uint256 public constant BASE_TOKENS = 1e18;
    uint64 public constant BASE_PARAMS = 1e9;

    function deployUpgradeable(address implementation, bytes memory data) public returns (address) {
        return address(new TransparentUpgradeableProxy(implementation, PROXY_ADMIN, data));
    }
}
