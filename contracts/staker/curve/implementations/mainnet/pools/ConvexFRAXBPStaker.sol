// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/staker/curve/implementations/mainnet/ConvexTokenStakerMainnet.sol";

/// @title ConvexFRAXBPStaker
/// @author Angle Labs, Inc.
/// @dev Implementation of `ConvexTokenStakerMainnet` for the FRAXBP pool
contract ConvexFRAXBPStaker is ConvexTokenStakerMainnet {
    // ============================= VIRTUAL FUNCTIONS =============================

    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
    }

    /// @inheritdoc ConvexTokenStakerMainnet
    function baseRewardPool() public pure override returns (IConvexBaseRewardPool) {
        return IConvexBaseRewardPool(0x7e880867363A7e321f5d260Cade2B0Bb2F717B02);
    }

    /// @inheritdoc ConvexTokenStaker
    function poolPid() public pure override returns (uint256) {
        return 100;
    }
}
