// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../StakeDAOTokenStaker.sol";

/// @title StakeDAOAgEURvEUROCStaker
/// @author Angle Labs, Inc.
/// @dev Implementation of `StakeDAOTokenStaker` for the agEUR-EUROC pool
contract StakeDAOAgEURvEUROCStaker is StakeDAOTokenStaker {
    // ============================= VIRTUAL FUNCTIONS =============================
    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0xBa3436Fd341F2C8A928452Db3C5A3670d1d5Cc73);
    }

    /// @inheritdoc StakeDAOTokenStaker
    function _vault() internal pure override returns (IStakeCurveVault) {
        return IStakeCurveVault(0xDe46532a49c88af504594F488822F452b7FBc7BD);
    }

    /// @inheritdoc StakeDAOTokenStaker
    function _gauge() internal pure override returns (ILiquidityGauge) {
        return ILiquidityGauge(0x63f222079608EEc2DDC7a9acdCD9344a21428Ce7);
    }
}
