// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../AuraTokenStaker.sol";

/// @title AuraWETHWSTETHStaker
/// @author Angle Labs, Inc.
/// @dev Implementation of `AuraTokenStaker` for the wETH/wstETH pool
contract AuraWETHWSTETHStaker is AuraTokenStaker {
    /// @inheritdoc BorrowStaker
    function asset() public pure override returns (IERC20) {
        return IERC20(0x32296969Ef14EB0c6d29669C550D4a0449130230);
    }

    /// @inheritdoc AuraTokenStaker
    function poolPid() public pure override returns (uint256) {
        return 3;
    }

    /// @inheritdoc AuraTokenStaker
    function baseRewardPool() public pure override returns (IConvexBaseRewardPool) {
        return IConvexBaseRewardPool(0xDCee1C640cC270121faF145f231fd8fF1d8d5CD4);
    }

    /// @inheritdoc AuraTokenStaker
    function liquidityGauge() public pure override returns (ILiquidityGaugeComplete) {
        return ILiquidityGaugeComplete(0xcD4722B7c24C29e0413BDCd9e51404B4539D14aE);
    }
}
