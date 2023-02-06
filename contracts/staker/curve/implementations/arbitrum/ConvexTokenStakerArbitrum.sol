// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../ConvexTokenStaker.sol";

/// @title ConvexTokenStakerArbitrum
/// @author Angle Labs, Inc.
/// @dev Constants for borrow staker adapted to Curve LP tokens deposited on Convex Arbitrum
abstract contract ConvexTokenStakerArbitrum is ConvexTokenStaker {
    /// @inheritdoc ERC20Upgradeable
    function _afterTokenTransfer(
        address from,
        address,
        uint256 amount
    ) internal override {
        // Stake on Convex if it is a deposit
        if (from == address(0)) {
            // Deposit the Curve LP tokens into the convex contract and stake
            _changeAllowance(asset(), address(_convexBooster()), amount);
            _convexBooster().deposit(poolPid(), amount);
        }
    }

    /// @inheritdoc BorrowStaker
    /// @dev If there are child rewards better to claim via Convex Zap Reward
    function _claimGauges() internal virtual override {
        // Claim on Convex
        baseRewardPool().getReward(address(this));
    }

    /// @inheritdoc BorrowStaker
    function _getRewards() internal pure override returns (IERC20[] memory rewards) {
        rewards = new IERC20[](1);
        rewards[0] = _crv();
        return rewards;
    }

    /// @inheritdoc ConvexTokenStaker
    function _crv() internal pure override returns (IERC20) {
        return IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    }

    // ========================== CONVEX-RELATED CONSTANTS =========================

    /// @inheritdoc ConvexTokenStaker
    function _convexBooster() internal pure override returns (IConvexBooster) {
        return IConvexBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    }

    /// @inheritdoc ConvexTokenStaker
    function _convexClaimZap() internal pure override returns (IConvexClaimZap) {
        return IConvexClaimZap(0xDd49A93FDcae579AE50B4b9923325e9e335ec82B);
    }

    /// @inheritdoc ConvexTokenStaker
    /// @dev No CVX tokens on Arbitrum/ no rewards in CVX
    function _cvx() internal pure override returns (IConvexToken) {
        return IConvexToken(address(0));
    }
}
