// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/staker/curve/implementations/arbitrum/StakeDAOTokenStakerArbitrum.sol";

/// @title StakeDAO2PoolStaker
/// @author Angle Labs, Inc.
/// @dev Implementation of `StakeDAOTokenStakerArbitrum` for the 2pool
contract StakeDAO2PoolStaker is StakeDAOTokenStakerArbitrum {
    // ============================= VIRTUAL FUNCTIONS =============================

    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0x7f90122BF0700F9E7e1F688fe926940E8839F353);
    }

    /// @inheritdoc StakeDAOTokenStaker
    function _vault() internal pure override returns (IStakeCurveVault) {
        return IStakeCurveVault(0x0f958528718b625c3aebd305dd2917a37570C56a);
    }

    /// @inheritdoc StakeDAOTokenStaker
    function _gauge() internal pure override returns (ILiquidityGauge) {
        return ILiquidityGauge(0x044f4954937316db6502638065b95E921Fd28475);
    }
}
