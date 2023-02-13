// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../CurveTokenStaker.sol";

/// @title CurveTokenStakerMainnet
/// @author Angle Labs, Inc.
/// @dev Constants for borrow staker adapted to Curve LP tokens deposited on Curve Mainnet
abstract contract CurveTokenStakerMainnet is CurveTokenStaker {
    /// @inheritdoc CurveTokenStaker
    function _crv() internal pure override returns (IERC20) {
        return IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    }
}
