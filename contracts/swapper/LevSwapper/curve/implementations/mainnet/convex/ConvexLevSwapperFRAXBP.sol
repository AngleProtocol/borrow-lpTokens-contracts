// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../CurveLevSwapperFRAXBP.sol";

/// @title ConvexLevSwapperFRAXBP
/// @author Angle Labs, Inc.
/// @notice Implements CurveLevSwapperFRAXBP with a Convex staker
contract ConvexLevSwapperFRAXBP is CurveLevSwapperFRAXBP {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter
    ) CurveLevSwapperFRAXBP(_core, _uniV3Router, _oneInch, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }
}
