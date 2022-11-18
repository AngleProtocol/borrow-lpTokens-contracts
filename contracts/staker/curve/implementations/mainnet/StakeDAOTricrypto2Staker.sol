// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import "../../StakeDAOTokenStaker.sol";

/// @title StakeDAOTricrypto2Staker
/// @author Angle Labs, Inc.
/// @dev Implementation of `StakeDAOTokenStaker` for the tricrypto2 pool
contract StakeDAOTricrypto2Staker is StakeDAOTokenStaker {
    // ============================= VIRTUAL FUNCTIONS =============================
    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0xc4AD29ba4B3c580e6D59105FFf484999997675Ff);
    }

    /// @notice StakeDAO Vault address
    function _vault() internal pure override returns (IStakeCurveVault) {
        return IStakeCurveVault(0x903f3c7B4c3b18DF9A06157F9FD5176E6a1fDe68);
    }

    /// @notice StakeDAO Gauge address
    function _gauge() internal pure override returns (ILiquidityGauge) {
        return ILiquidityGauge(0x4D69ad5F243571AA9628bd88ebfFA2C913427b0b);
    }
}
