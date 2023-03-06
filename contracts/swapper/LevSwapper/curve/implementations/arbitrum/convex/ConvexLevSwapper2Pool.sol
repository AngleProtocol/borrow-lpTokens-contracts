// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../CurveLevSwapper2Pool.sol";

/// @title ConvexLevSwapper2Pool
/// @author Angle Labs, Inc.
/// @notice Implements CurveLevSwapper2Pool with a Convex staker
contract ConvexLevSwapper2Pool is CurveLevSwapper2Pool {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter
    ) CurveLevSwapper2Pool(_core, _uniV3Router, _oneInch, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(0x42dC54fb50dB556fA6ffBa765F1141536d4830ea);
    }
}
