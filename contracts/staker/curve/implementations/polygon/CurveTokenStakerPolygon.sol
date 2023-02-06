// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../CurveTokenStaker.sol";

/// @title CurveTokenStakerPolygon
/// @author Angle Labs, Inc.
/// @dev Constants for borrow staker adapted to Curve LP tokens deposited on Curve Polygon
abstract contract CurveTokenStakerPolygon is CurveTokenStaker {
    /// @inheritdoc BorrowStaker
    function _getRewards() internal pure override returns (IERC20[] memory rewards) {
        rewards = new IERC20[](1);
        rewards[0] = _crv();
        return rewards;
    }

    /// @notice Address of the CRV token
    function _crv() internal pure returns (IERC20) {
        return IERC20(0x172370d5Cd63279eFa6d502DAB29171933a610AF);
    }
}
