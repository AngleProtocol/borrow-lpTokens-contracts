// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../StakeDAOTokenStaker.sol";

/// @title StakeDAO3CRVStaker
/// @author Angle Labs, Inc.
/// @dev Implementation of `StakeDAOTokenStaker` for the 3CRV pool
contract StakeDAO3CRVStaker is StakeDAOTokenStaker {
    // ============================= VIRTUAL FUNCTIONS =============================
    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    }

    /// @inheritdoc StakeDAOTokenStaker
    function _vault() internal pure override returns (IStakeCurveVault) {
        return IStakeCurveVault(0xB17640796e4c27a39AF51887aff3F8DC0daF9567);
    }

    /// @inheritdoc StakeDAOTokenStaker
    function _gauge() internal pure override returns (ILiquidityGauge) {
        return ILiquidityGauge(0xCc640eaf32BD2ac28A6Dd546eB2D713c3bCaF321);
    }
}
