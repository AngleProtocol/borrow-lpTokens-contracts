// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../StakeDAOTokenStakerMainnet.sol";

/// @title StakeDAOTricrypto2Staker
/// @author Angle Labs, Inc.
/// @dev Implementation of `StakeDAOTokenStakerMainnet` for the Tricrypto2 pool
contract StakeDAOTricrypto2Staker is StakeDAOTokenStakerMainnet {
    // ============================= VIRTUAL FUNCTIONS =============================
    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0xc4AD29ba4B3c580e6D59105FFf484999997675Ff);
    }

    /// @inheritdoc StakeDAOTokenStaker
    function _vault() internal pure override returns (IStakeCurveVault) {
        return IStakeCurveVault(0x903f3c7B4c3b18DF9A06157F9FD5176E6a1fDe68);
    }

    /// @inheritdoc StakeDAOTokenStaker
    function _gauge() internal pure override returns (ILiquidityGauge) {
        return ILiquidityGauge(0x4D69ad5F243571AA9628bd88ebfFA2C913427b0b);
    }
}
