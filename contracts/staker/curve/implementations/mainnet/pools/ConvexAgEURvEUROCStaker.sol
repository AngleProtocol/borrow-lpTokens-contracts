// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/staker/curve/implementations/mainnet/ConvexTokenStakerMainnet.sol";

/// @title ConvexAgEURvEUROCStaker
/// @author Angle Labs, Inc.
/// @dev Implementation of `ConvexTokenStakerMainnet` for the agEUR-EUROC pool
contract ConvexAgEURvEUROCStaker is ConvexTokenStakerMainnet {
    // ============================= VIRTUAL FUNCTIONS =============================

    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0xBa3436Fd341F2C8A928452Db3C5A3670d1d5Cc73);
    }

    /// @inheritdoc ConvexTokenStakerMainnet
    function baseRewardPool() public pure override returns (IConvexBaseRewardPool) {
        return IConvexBaseRewardPool(0xA91fccC1ec9d4A2271B7A86a7509Ca05057C1A98);
    }

    /// @inheritdoc ConvexTokenStaker
    function poolPid() public pure override returns (uint256) {
        return 113;
    }
}
