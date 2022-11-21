// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import "../../ConvexTokenStaker.sol";

/// @title ConvexTricrypto2Staker
/// @author Angle Labs, Inc.
/// @dev Implementation of `ConvexTokenStaker` for the Tricrypto2 pool
contract ConvexTricrypto2Staker is ConvexTokenStaker {
    // ============================= VIRTUAL FUNCTIONS =============================

    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0xc4AD29ba4B3c580e6D59105FFf484999997675Ff);
    }

    /// @notice Address of the Convex contract on which to claim rewards
    function baseRewardPool() public pure override returns (IConvexBaseRewardPool) {
        return IConvexBaseRewardPool(0x9D5C5E364D81DaB193b72db9E9BE9D8ee669B652);
    }

    /// @notice ID of the pool associated to the AMO on Convex
    function poolPid() public pure override returns (uint256) {
        return 38;
    }
}
