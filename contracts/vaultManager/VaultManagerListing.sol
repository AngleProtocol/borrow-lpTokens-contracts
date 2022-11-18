// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import { IBorrowStakerCheckpoint } from "../interfaces/IBorrowStaker.sol";
import "./VaultManager.sol";

/// @title VaultManagerListing
/// @author Angle Labs, Inc.
/// @notice Provides an additional viewer to `VaultManager` to get the full collateral deposited
/// by an owner
/// @dev This implementation is built to interact with `collateral` that are in fact `staker` contracts wrapping
/// another collateral asset.
/// @dev Some things are worth noting regarding transfers and updates in the `totalBalanceOf` for such `collateral`.
/// When adding or removing collateral to/from a vault, the `totalBalanceOf` of an address is updated, even if the asset
/// has not been transferred yet, meaning there can be two checkpoints for in fact a single transfer.
/// Adding collateral to a vault increases the total balance of the `sender`. But after the vault collateral increase,
/// since the `sender` still owns the `collateral`, there is a double count in the total balance. This is not a
/// problem as the `sender` was already checkpointed in the `_addCollateral`.
/// In the case of a `burn` or `removeCollateral` action, there is a first checkpoint with the correct balances,
/// and then a second one when the vault transfers the `collateral` with a deflated balance in this case.
/// Conclusion is that the logic on which this contract is built is working as expected as long as no rewards
/// are distributed within a same tx from the staking contract. Most protocols already follow this hypothesis,
/// but for those who don't, this vault implementation doesn't work
/// Note that it is a weaker assumption than what is done in the `staker` contract which supposes that no rewards
/// can be distributed to the same address within a block
contract VaultManagerListing is VaultManager {
    using SafeERC20 for IERC20;
    using Address for address;

    // ================================== STORAGE ==================================

    // @notice Mapping from owner address to all his vaults
    mapping(address => uint256[]) internal _ownerListVaults;

    uint256[49] private __gapListing;

    // =============================== VIEW FUNCTIONS ==============================

    /// @notice Get the collateral owned by the user in the contract
    function getUserCollateral(address user) external view returns (uint256 totalCollateral) {
        uint256[] memory vaultList = _ownerListVaults[user];
        uint256 vaultListLength = vaultList.length;
        for (uint256 k; k < vaultListLength; ++k) {
            totalCollateral += vaultData[vaultList[k]].collateralAmount;
        }
        return totalCollateral;
    }

    // ================= INTERNAL UTILITY STATE-MODIFYING FUNCTIONS ================

    /// @inheritdoc VaultManagerERC721
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 vaultID
    ) internal override {
        // if this is not a mint remove from the `from` vault list `vaultID`
        if (from != address(0)) {
            _checkpointWrapper(from);
            _removeVaultFromList(from, vaultID);
        }
        if (to != address(0)) {
            // If it is a mint we don't need to checkpoint as it is only useful when funds are deposited
            // But when we transfer the vault we should definitely checkpoint
            if (from != address(0)) _checkpointWrapper(to);
            _ownerListVaults[to].push(vaultID);
        }
    }

    /// @inheritdoc VaultManager
    /// @dev Checkpoints the staker associated to the `collateral` of the contract after an update of the
    /// `collateralAmount` of vaultID
    function _checkpointCollateral(uint256 vaultID, bool burn) internal override {
        address owner = _ownerOf(vaultID);
        _checkpointWrapper(owner);
        if (burn) _removeVaultFromList(owner, vaultID);
    }

    /// @notice Remove `vaultID` from `user` stroed vault list
    /// @param user Address to look out for the vault list
    /// @param vaultID VaultId to remove from the list
    /// @dev The vault is necessarily in the list
    function _removeVaultFromList(address user, uint256 vaultID) internal {
        uint256[] storage vaultList = _ownerListVaults[user];
        uint256 vaultListLength = vaultList.length;
        for (uint256 i; i < vaultListLength - 1; ++i) {
            if (vaultList[i] == vaultID) {
                vaultList[i] = vaultList[vaultListLength - 1];
                break;
            }
        }
        vaultList.pop();
    }

    /// @notice Checkpoint rewards for `user` in the `staker` contract
    /// @param user Address to look out for the vault list
    /// @dev Whenever there is an internal transfer or a transfer from the `vaultManager`,
    /// we need to update the rewards to correctly track everyone's claim
    function _checkpointWrapper(address user) internal {
        IBorrowStakerCheckpoint(address(collateral)).checkpoint(user);
    }
}
