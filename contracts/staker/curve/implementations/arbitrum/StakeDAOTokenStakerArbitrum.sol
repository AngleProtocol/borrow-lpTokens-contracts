// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../StakeDAOTokenStaker.sol";

/// @title StakeDAOTokenStakerArbitrum
/// @author Angle Labs, Inc.
/// @dev Constants for borrow staker adapted to Curve LP tokens deposited on Stake DAO Arbitrum
abstract contract StakeDAOTokenStakerArbitrum is StakeDAOTokenStaker {
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
