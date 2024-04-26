// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/curve/implementations/polygon/CurveLevSwapperTricrypto3.sol";

/// @title CurveLevSwapperTricrypto3
/// @author Angle Labs, Inc.
/// @notice Implements a leverage swapper to gain/reduce exposure to the Polygon tricrypto3 Curve LP token
contract MockCurveLevSwapper3TokensWithBP is CurveLevSwapperTricrypto3 {
    IBorrowStaker internal _angleStaker;

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter,
        IBorrowStaker angleStaker_
    ) CurveLevSwapperTricrypto3(_core, _uniV3Router, _aggregator, _angleRouter) {
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
