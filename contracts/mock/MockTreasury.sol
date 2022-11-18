// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "../interfaces/ITreasury.sol";
import "../interfaces/IFlashAngle.sol";
import "../interfaces/IVaultManager.sol";
import "../interfaces/ICoreBorrow.sol";

contract MockTreasury is ITreasury {
    IAgToken public override stablecoin;
    ICoreBorrow public core;
    /// @notice List of the accepted `VaultManager` of the protocol
    address[] public vaultManagerList;
    /// @notice Maps an address to 1 if it was initialized as a `VaultManager` contract
    mapping(address => uint256) public vaultManagerMap;

    error AlreadyVaultManager();
    error NotVaultManager();
    error InvalidTreasury();

    constructor(ICoreBorrow _core, IAgToken _stablecoin) {
        stablecoin = _stablecoin;
        core = _core;
    }

    /// @inheritdoc ITreasury
    function isGovernor(address admin) external view returns (bool) {
        return core.isGovernor(admin);
    }

    /// @inheritdoc ITreasury
    function isGovernorOrGuardian(address admin) external view returns (bool) {
        return core.isGovernorOrGuardian(admin);
    }

    /// @inheritdoc ITreasury
    function isVaultManager(address _vaultManager) external view returns (bool) {
        return vaultManagerMap[_vaultManager] == 1;
    }

    function setStablecoin(IAgToken _stablecoin) external {
        stablecoin = _stablecoin;
    }

    function setFlashLoanModule(address _flashLoanModule) external {}

    /// @notice Adds a new `VaultManager`
    /// @param vaultManager `VaultManager` contract to add
    /// @dev This contract should have already been initialized with a correct treasury address
    /// @dev It's this function that gives the minter right to the `VaultManager`
    function addVaultManager(address vaultManager) external {
        if (vaultManagerMap[vaultManager] == 1) revert AlreadyVaultManager();
        if (address(IVaultManager(vaultManager).treasury()) != address(this)) revert InvalidTreasury();
        vaultManagerMap[vaultManager] = 1;
        vaultManagerList.push(vaultManager);
        stablecoin.addMinter(vaultManager);
    }

    /// @notice Removes a `VaultManager`
    /// @param vaultManager `VaultManager` contract to remove
    /// @dev A removed `VaultManager` loses its minter right on the stablecoin
    function removeVaultManager(address vaultManager) external {
        if (vaultManagerMap[vaultManager] != 1) revert NotVaultManager();
        delete vaultManagerMap[vaultManager];
        // deletion from `vaultManagerList` loop
        uint256 vaultManagerListLength = vaultManagerList.length;
        for (uint256 i; i < vaultManagerListLength - 1; ++i) {
            if (vaultManagerList[i] == vaultManager) {
                // replace the `VaultManager` to remove with the last of the list
                vaultManagerList[i] = vaultManagerList[vaultManagerListLength - 1];
                break;
            }
        }
        // remove last element in array
        vaultManagerList.pop();
        stablecoin.removeMinter(vaultManager);
    }

    function setTreasury(address _agTokenOrVaultManager, address _treasury) external {
        IAgToken(_agTokenOrVaultManager).setTreasury(_treasury);
    }

    function addMinter(IAgToken _agToken, address _minter) external {
        _agToken.addMinter(_minter);
    }

    function removeMinter(IAgToken _agToken, address _minter) external {
        _agToken.removeMinter(_minter);
    }

    function accrueInterestToTreasury(IFlashAngle flashAngle) external returns (uint256 balance) {
        balance = flashAngle.accrueInterestToTreasury(stablecoin);
    }

    function accrueInterestToTreasuryVaultManager(IVaultManager _vaultManager) external returns (uint256, uint256) {
        return _vaultManager.accrueInterestToTreasury();
    }
}
