// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../../../swapper/LevSwapper/curve/implementations/arbitrum/CurveLevSwapper2Pool.sol";

/// @title MockCurveLevSwapper2Pool
/// @author Angle Labs, Inc.
/// @notice Implements a leverage swapper to gain/reduce exposure to the 2Pool Curve LP token
contract MockCurveLevSwapper2Pool is CurveLevSwapper2Pool {
    IBorrowStaker internal _angleStaker;

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter,
        IBorrowStaker angleStaker_
    ) CurveLevSwapper2Pool(_core, _uniV3Router, _aggregator, _angleRouter) {
        _angleStaker = angleStaker_;
    }

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public view override returns (IBorrowStaker) {
        return _angleStaker;
    }

    function setAngleStaker(IBorrowStaker angleStaker_) public {
        _angleStaker = angleStaker_;
    }
}
