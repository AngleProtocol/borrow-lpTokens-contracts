// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../ConvexTokenStaker.sol";

/// @title ConvexFRAXBPStaker
/// @author Angle Labs, Inc.
/// @dev Implementation of `ConvexTokenStaker` for the FRAXBP pool
contract ConvexFRAXBPStaker is ConvexTokenStaker {
    // ============================= VIRTUAL FUNCTIONS =============================

    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
    }

    /// @notice Address of the Convex contract on which to claim rewards
    function baseRewardPool() public pure override returns (IConvexBaseRewardPool) {
        return IConvexBaseRewardPool(0x7e880867363A7e321f5d260Cade2B0Bb2F717B02);
    }

    /// @notice ID of the pool associated to the AMO on Convex
    function poolPid() public pure override returns (uint256) {
        return 100;
    }
}
