// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../CurveTokenStaker.sol";

/// @title CurveTokenStakerArbitrum
/// @author Angle Labs, Inc.
/// @dev Constants for borrow staker adapted to Curve LP tokens deposited on Curve Arbitrum
abstract contract CurveTokenStakerArbitrum is CurveTokenStaker {
    /// @inheritdoc BorrowStaker
    function _getRewards() internal pure override returns (IERC20[] memory rewards) {
        rewards = new IERC20[](1);
        rewards[0] = _crv();
        return rewards;
    }

    /// @notice Address of the CRV token
    function _crv() internal pure returns (IERC20) {
        return IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    }
}
