// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../ConvexTokenStakerMainnet.sol";

/// @title ConvexTricrypto2Staker
/// @author Angle Labs, Inc.
/// @dev Implementation of `ConvexTokenStaker` for the Tricrypto2 pool
contract ConvexTricrypto2Staker is ConvexTokenStaker {
    // ============================= VIRTUAL FUNCTIONS =============================

    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0xc4AD29ba4B3c580e6D59105FFf484999997675Ff);
    }

    /// @inheritdoc ConvexTokenStaker
    function baseRewardPool() public pure override returns (IConvexBaseRewardPool) {
        return IConvexBaseRewardPool(0x9D5C5E364D81DaB193b72db9E9BE9D8ee669B652);
    }

    /// @inheritdoc ConvexTokenStaker
    function poolPid() public pure override returns (uint256) {
        return 38;
    }
}
