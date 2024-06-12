// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "borrow/interfaces/IOracle.sol";
import { IERC20, VaultParameters, VaultManagerListing } from "borrow-staked/vaultManager/VaultManagerListing.sol";
import "./ArbitrumConstants.s.sol";
import "../UtilsUpgradable.s.sol";

contract DeployVaultManagerArbitrum is Script, ArbitrumConstants, UtilsUpgradable {
    VaultManagerListing public constant VAULT_MANAGER_IMPL =
        VaultManagerListing(0x8928d0C942CA48Ea86F458857de61b92D6f5A564);
    // TODO to be changed at deployment depending on the vaultManager
    IOracle public constant ORACLE = IOracle(0x9De6Efe3454F8EFF8C8C8d1314CD019AF2432e59);
    // the staker address
    IERC20 public constant COLLATERAL_CONVEX = IERC20(0x42dC54fb50dB556fA6ffBa765F1141536d4830ea);
    IERC20 public constant COLLATERAL_STAKEDAO = IERC20(0xc8711B1206cD3e89799Ec32973f583e696Cb553C);

    string public constant SYMBOL_CONVEX = "cvx-crvUSDCUSDT";
    string public constant SYMBOL_STAKEDAO = "sd-crvUSDCUSDT";
    uint256 public constant DEBT_CEILING = 50000 ether;
    uint64 public constant CF = (8 * BASE_PARAMS) / 10;
    uint64 public constant THF = (11 * BASE_PARAMS) / 10;
    uint64 public constant BORROW_FEE = 0;
    uint64 public constant REPAY_FEE = 0;
    uint64 public constant INTEREST_RATE = 158153934393112649;
    uint64 public constant LIQUIDATION_SURCHARGE = (98 * BASE_PARAMS) / 100;
    uint64 public constant MAX_LIQUIDATION_DISCOUNT = (9 * BASE_PARAMS) / 100;
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

        uint256 deployerPrivateKey = vm.deriveKey(vm.envString("MNEMONIC_ARBITRUM"), 0);
        vm.startBroadcast(deployerPrivateKey);

        if (
            address(VAULT_MANAGER_IMPL) == address(0) ||
            address(ORACLE) == address(0) ||
            address(COLLATERAL_CONVEX) == address(0)
        ) revert ZeroAdress();

        vaultManagerConvex = VaultManagerListing(
            deployUpgradeable(
                PROXY_ADMIN,
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

        console.log("Successfully deployed vaultManager Convex 2 Pool at the address: ", address(vaultManagerConvex));

        if (
            address(VAULT_MANAGER_IMPL) == address(0) ||
            address(ORACLE) == address(0) ||
            address(COLLATERAL_STAKEDAO) == address(0)
        ) revert ZeroAdress();

        vaultManagerStakeDAO = VaultManagerListing(
            deployUpgradeable(
                PROXY_ADMIN,
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

        console.log(
            "Successfully deployed vaultManager StakeDAO 2 Pool at the address: ",
            address(vaultManagerStakeDAO)
        );

        // TODO Governor/Guardian call to add addVaultManager on the `staker`

        vm.stopBroadcast();
    }
}
