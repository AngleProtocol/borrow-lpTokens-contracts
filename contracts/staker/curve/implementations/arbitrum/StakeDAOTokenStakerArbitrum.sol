// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../StakeDAOTokenStaker.sol";

/// @title StakeDAOTokenStakerArbitrum
/// @author Angle Labs, Inc.
/// @dev Constants for borrow staker adapted to Curve LP tokens deposited on Stake DAO Arbitrum
abstract contract StakeDAOTokenStakerArbitrum is StakeDAOTokenStaker {
    /// @inheritdoc ERC20Upgradeable
    function _afterTokenTransfer(address from, address, uint256 amount) internal virtual override {
        // Stake on StakeDAO if it is a deposit
        if (from == address(0)) {
            // Approve the vault contract for the Curve LP tokens
            _changeAllowance(asset(), address(_vault()), amount);
            // Deposit the Curve LP tokens into the vault contract and stake
            _vault().deposit(address(this), amount);
        }
    }

    /// @inheritdoc StakeDAOTokenStaker
    function _withdrawalFee() internal pure override returns (uint256) {
        return 0;
    }

    /// @inheritdoc BorrowStaker
    function _getRewards() internal pure override returns (IERC20[] memory rewards) {
        rewards = new IERC20[](2);
        rewards[0] = _crv();
        rewards[1] = _arb();
        return rewards;
    }

    /// @notice Address of the CRV token
    function _crv() internal pure returns (IERC20) {
        return IERC20(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
    }

    /// @notice Address of the CRV token
    function _arb() internal pure returns (IERC20) {
        return IERC20(0x912CE59144191C1204E64559FE8253a0e49E6548);
    }
}
