// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../StakeDAOTokenStaker.sol";

/// @title StakeDAOLUSDv3CRVStaker
/// @author Angle Labs, Inc.
/// @dev Implementation of `StakeDAOTokenStaker` for the LUSD-3CRV pool
contract StakeDAOLUSDv3CRVStaker is StakeDAOTokenStaker {
    // ============================= VIRTUAL FUNCTIONS =============================
    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    }

    /// @inheritdoc StakeDAOTokenStaker
    function _vault() internal pure override returns (IStakeCurveVault) {
        return IStakeCurveVault(0xfB5312107c4150c86228e8fd719b8b0Ae2db581d);
    }

    /// @inheritdoc StakeDAOTokenStaker
    function _gauge() internal pure override returns (ILiquidityGauge) {
        return ILiquidityGauge(0x3794C7C69B9c761ede266A9e8B8bb0f6cdf4E3E5);
    }
}