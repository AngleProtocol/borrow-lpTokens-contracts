// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "borrow/interfaces/IOracle.sol";
import { IERC20, VaultParameters, VaultManagerListing } from "../../../contracts/vaultManager/VaultManagerListing.sol";
import "./MainnetConstants.s.sol";

contract DeployVaultManagerMainnet is Script, MainnetConstants {
    VaultManagerListing public constant VAULT_MANAGER_IMPL =
        VaultManagerListing(0xCe43220f72A7060F34BC242630D6B96434105Ae4);
    // TODO to be changed at deployment depending on the vaultManager
    IOracle public constant ORACLE = IOracle(address(0));
    // the staker address
    IERC20 public constant COLLATERAL_CONVEX = IERC20(address(0));
    IERC20 public constant COLLATERAL_STAKEDAO = IERC20(address(0));

    string public constant SYMBOL_CONVEX = "cvx-3CRV";
    string public constant SYMBOL_STAKEDAO = "sd-3CRV";
    uint256 public constant DEBT_CEILING = 100_000 ether;
    uint64 public constant CF = (8 * BASE_PARAMS) / 10;
    uint64 public constant THF = (105 * BASE_PARAMS) / 100;
    uint64 public constant BORROW_FEE = 0;
    uint64 public constant REPAY_FEE = 0;
    uint64 public constant INTEREST_RATE = 158153934393112649;
    uint64 public constant LIQUIDATION_SURCHARGE = (98 * BASE_PARAMS) / 100;
    uint64 public constant MAX_LIQUIDATION_DISCOUNT = (8 * BASE_PARAMS) / 100;
    bool public constant WHITELISTING_ACTIVATED = false;
    uint256 public constant BASE_BOOST = (15 * BASE_PARAMS) / 10;

    VaultManagerListing public vaultManagerConvex;
    VaultManagerListing public vaultManagerStakeDAO;

    error ZeroAdress();

    function run() external {
        VaultParameters memory paramsConvex = VaultParameters({
            debtCeiling: DEBT_CEILING,
            collateralFactor: CF,
            targetHealthFactor: THF,
            interestRate: INTEREST_RATE,
            liquidationSurcharge: LIQUIDATION_SURCHARGE,
            maxLiquidationDiscount: MAX_LIQUIDATION_DISCOUNT,
            whitelistingActivated: WHITELISTING_ACTIVATED,
            baseBoost: BASE_BOOST
        });
        VaultParameters memory paramsStakedao = VaultParameters({
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
            address(COLLATERAL_CONVEX) == address(0)
        ) revert ZeroAdress();

        vaultManagerConvex = VaultManagerListing(
            deployUpgradeable(
                address(VAULT_MANAGER_IMPL),
                abi.encodeWithSelector(
                    VAULT_MANAGER_IMPL.initialize.selector,
                    AGEUR_TREASURY,
                    COLLATERAL_CONVEX,
                    ORACLE,
                    paramsConvex,
                    SYMBOL_CONVEX
                )
            )
        );

        console.log("Successfully deployed vaultManager Convex 3CRV at the address: ", address(vaultManagerConvex));

        if (
            address(VAULT_MANAGER_IMPL) == address(0) ||
            address(ORACLE) == address(0) ||
            address(COLLATERAL_STAKEDAO) == address(0)
        ) revert ZeroAdress();

        vaultManagerStakeDAO = VaultManagerListing(
            deployUpgradeable(
                address(VAULT_MANAGER_IMPL),
                abi.encodeWithSelector(
                    VAULT_MANAGER_IMPL.initialize.selector,
                    AGEUR_TREASURY,
                    COLLATERAL_STAKEDAO,
                    ORACLE,
                    paramsStakedao,
                    SYMBOL_STAKEDAO
                )
            )
        );

        console.log("Successfully deployed vaultManager StakeDAO 3CRV at the address: ", address(vaultManagerStakeDAO));

        // TODO Governor/Guardian call to add addVaultManager on the `staker`
        // TODO add call unpaused
        // TODO add call dust

        vm.stopBroadcast();
    }
}
