// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "borrow/interfaces/IOracle.sol";
import { IERC20, VaultParameters, VaultManagerListing } from "../../../contracts/vaultManager/VaultManagerListing.sol";
import "./MainnetConstants.s.sol";

contract DeployVaultManagerMainnet is Script, MainnetConstants {
    // TODO to be changed at deployment depending on the vaultManager
    VaultManagerListing public constant VAULT_MANAGER_IMPL = VaultManagerListing(address(0));
    IOracle public constant ORACLE = IOracle(address(0));
    // the staker address
    IERC20 public constant COLLATERAL = IERC20(0xe1Bc17f85d54a81068FC510d5A94E95800D342d9);

    string public constant SYMBOL = "cvxcrvFRAX-EUR";
    uint256 public constant DEBT_CEILING = 100 ether;
    uint64 public constant CF = (8 * BASE_PARAMS) / 10;
    uint64 public constant THF = (105 * BASE_PARAMS) / 100;
    uint64 public constant BORROW_FEE = 0;
    uint64 public constant REPAY_FEE = 0;
    uint64 public constant INTEREST_RATE = 158153934393112649;
    uint64 public constant LIQUIDATION_SURCHARGE = (98 * BASE_PARAMS) / 100;
    uint64 public constant MAX_LIQUIDATION_DISCOUNT = (8 * BASE_PARAMS) / 100;
    bool public constant WHITELISTING_ACTIVATED = false;
    uint256 public constant BASE_BOOST = (25 * BASE_PARAMS) / 100;

    VaultManagerListing public vaultManager;

    error ZeroAdress();

    function run() external {
        VaultParameters memory params = VaultParameters({
            debtCeiling: DEBT_CEILING,
            collateralFactor: CF,
            targetHealthFactor: THF,
            interestRate: INTEREST_RATE,
            liquidationSurcharge: LIQUIDATION_SURCHARGE,
            maxLiquidationDiscount: MAX_LIQUIDATION_DISCOUNT,
            whitelistingActivated: WHITELISTING_ACTIVATED,
            baseBoost: BASE_BOOST
        });

        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_MAINNET"), 0);
        vm.startBroadcast(deployerPrivateKey);

        if (
            address(VAULT_MANAGER_IMPL) == address(0) ||
            address(ORACLE) == address(0) ||
            address(COLLATERAL) == address(0)
        ) revert ZeroAdress();

        vaultManager = VaultManagerListing(
            deployUpgradeable(
                address(VAULT_MANAGER_IMPL),
                abi.encodeWithSelector(
                    VAULT_MANAGER_IMPL.initialize.selector,
                    AGEUR_TREASURY,
                    COLLATERAL,
                    ORACLE,
                    params,
                    SYMBOL
                )
            )
        );

        console.log("Successfully deployed vaultManager Convex FRAXBP at the address: ", address(vaultManager));

        // TODO Governor/Guardian call to add addVaultManager on the `staker`

        vm.stopBroadcast();
    }
}
