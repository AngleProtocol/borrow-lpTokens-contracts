// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/staker/angle/SanTokenStaker.sol";

/// @title SanTokenUSDCvAgEURStaker
/// @author Angle Labs, Inc.
contract SanTokenUSDCvAgEURStaker is SanTokenStaker {
    // ============================= VIRTUAL FUNCTIONS =============================

    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0x9C215206Da4bf108aE5aEEf9dA7caD3352A36Dad);
    }

    /// @dev use the sanUSDCEUR gauge
    function liquidityGauge() public pure override returns (ILiquidityGauge) {
        return ILiquidityGauge(0x51fE22abAF4a26631b2913E417c0560D547797a7);
    }
}
