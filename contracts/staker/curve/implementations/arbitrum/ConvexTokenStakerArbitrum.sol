// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../ConvexTokenStaker.sol";
import { IConvexBaseRewardPoolSideChain, EarnedData } from "../../../../interfaces/external/convex/IBaseRewardPool.sol";

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
    function _withdrawFromProtocol(uint256 amount) internal override {
        baseRewardPool().withdraw(amount, false);
    }

    /// @inheritdoc BorrowStaker
    /// @dev If there are child rewards better to claim via Convex Zap Reward
    function _claimGauges() internal virtual override {
        baseRewardPool().getReward(address(this));
    }

    /// @inheritdoc BorrowStaker
    /// @dev If the token is not found in the `earned` list it will return 0 anyway
    function _rewardsToBeClaimed(IERC20 rewardToken) internal view override returns (uint256 amount) {
        EarnedData[] memory earnings = baseRewardPool().earned(address(this));
        uint256 earningsLength = earnings.length;
        for (uint256 i; i < earningsLength; ++i)
            if (earnings[i].token == address(rewardToken)) return earnings[i].amount;
    }

    /// @inheritdoc BorrowStaker
    function _getRewards() internal pure override returns (IERC20[] memory rewards) {
        rewards = new IERC20[](2);
        rewards[0] = _crv();
        rewards[1] = _cvx();
        return rewards;
    }

    /// @inheritdoc ConvexTokenStaker
    function _crv() internal pure override returns (IERC20) {
        return IERC20(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
    }

    // ========================== CONVEX-RELATED CONSTANTS =========================

    /// @inheritdoc ConvexTokenStaker
    function _convexBooster() internal pure override returns (IConvexBooster) {
        return IConvexBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    }

    /// @inheritdoc ConvexTokenStaker
    /// @dev Unused on Arbitrum
    function _convexClaimZap() internal pure override returns (IConvexClaimZap) {
        return IConvexClaimZap(address(0));
    }

    /// @inheritdoc ConvexTokenStaker
    /// @dev No CVX tokens on Arbitrum / no rewards in CVX
    function _cvx() internal pure override returns (IConvexToken) {
        return IConvexToken(address(0xb952A807345991BD529FDded05009F5e80Fe8F45));
    }

    // ============================= VIRTUAL FUNCTIONS =============================

    /// @notice Address of the Convex contract on which to claim rewards
    function baseRewardPool() public pure virtual returns (IConvexBaseRewardPoolSideChain);
}
