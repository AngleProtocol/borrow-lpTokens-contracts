// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../ConvexTokenStaker.sol";

/// @title ConvexTokenStakerMainnet
/// @author Angle Labs, Inc.
/// @dev Constants for borrow staker adapted to Curve LP tokens deposited on Convex Mainnet
abstract contract ConvexTokenStakerMainnet is ConvexTokenStaker {
    /// @inheritdoc BorrowStaker
    function _getRewards() internal pure override returns (IERC20[] memory rewards) {
        rewards = new IERC20[](2);
        rewards[0] = _crv();
        rewards[1] = _cvx();
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
    function _cvx() internal pure override returns (IConvexToken) {
        return IConvexToken(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);
    }
}
