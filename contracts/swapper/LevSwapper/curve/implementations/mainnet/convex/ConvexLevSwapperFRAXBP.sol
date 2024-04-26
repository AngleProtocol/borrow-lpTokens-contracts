// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/curve/implementations/mainnet/CurveLevSwapperFRAXBP.sol";

/// @title ConvexLevSwapperFRAXBP
/// @author Angle Labs, Inc.
/// @notice Implements CurveLevSwapperFRAXBP with a Convex staker
contract ConvexLevSwapperFRAXBP is CurveLevSwapperFRAXBP {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter
    ) CurveLevSwapperFRAXBP(_core, _uniV3Router, _aggregator, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(0xC68421f20bf6f0Eb475F00b9C5484f7D0AC0331e);
    }
}
