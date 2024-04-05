// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../CurveLevSwapperTricrypto3.sol";

/// @title CurveLevSwapperTricrypto3
/// @author Angle Labs, Inc
/// @notice Implements a leverage swapper to gain/reduce exposure to the Polygon tricrypto2 Curve LP token
/// with a moke staker
contract MockCurveLevSwapperTricrypto3 is CurveLevSwapperTricrypto3 {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter
    ) CurveLevSwapperTricrypto3(_core, _uniV3Router, _aggregator, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(0x36b41Bdd49265C6820f71002dC2FE5cB1Aa290fc);
    }
}
