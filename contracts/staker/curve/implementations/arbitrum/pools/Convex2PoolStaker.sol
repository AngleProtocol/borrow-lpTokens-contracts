// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../ConvexTokenStakerArbitrum.sol";

/// @title Convex2PoolStaker
/// @author Angle Labs, Inc.
/// @dev Implementation of `ConvexTokenStakerArbitrum` for the 2pool
contract Convex2PoolStaker is ConvexTokenStakerArbitrum {
    // ============================= VIRTUAL FUNCTIONS =============================

    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0x7f90122BF0700F9E7e1F688fe926940E8839F353);
    }

    /// @inheritdoc ConvexTokenStakerArbitrum
    function baseRewardPool() public pure override returns (IConvexBaseRewardPoolSideChain) {
        return IConvexBaseRewardPoolSideChain(0x63F00F688086F0109d586501E783e33f2C950e78);
    }

    /// @inheritdoc ConvexTokenStaker
    function poolPid() public pure override returns (uint256) {
        return 1;
    }
}
