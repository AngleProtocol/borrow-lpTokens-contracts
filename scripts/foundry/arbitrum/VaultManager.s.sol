// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import "borrow/interfaces/IOracle.sol";
import { IERC20, VaultParameters, VaultManagerListing } from "../../../contracts/vaultManager/VaultManagerListing.sol";
import "./ArbitrumConstants.s.sol";

contract DeployVaultManagerArbitrum is Script, ArbitrumConstants {
    // TODO to be changed at deployment depending on the vaultManager
    VaultManagerListing public constant VAULT_MANAGER_IMPL =
        VaultManagerListing(0xecb3F3CBdB0bE5D226D04C1b37139eDD16Ef5376);
    IOracle public constant ORACLE = IOracle(0x834787f9728A2797Df987AEEDb6d3D7446E93282);
    // the staker address
    IERC20 public constant COLLATERAL_CONVEX = IERC20(0xb7263cAD66A05f71875c4C4d2fB7A30DDE9b5656);
    IERC20 public constant COLLATERAL_STAKEDAO = IERC20(0xC9E4e9605c836a5647C87594f2b91725aE184b1A);

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
