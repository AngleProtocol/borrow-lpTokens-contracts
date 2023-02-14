// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../../../swapper/LevSwapper/curve/implementations/mainnet/CurveLevSwapper3CRV.sol";

/// @title MockCurveLevSwapper3Tokens
/// @author Angle Labs, Inc.
/// @notice Implements a leverage swapper to gain/reduce exposure to the 3CRV Curve LP token
contract MockCurveLevSwapper3CRV is CurveLevSwapper3CRV {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter,
        IBorrowStaker angleStaker_
    ) CurveLevSwapper3CRV(_core, _uniV3Router, _oneInch, _angleRouter, angleStaker_) {}

    function setAngleStaker(IBorrowStaker angleStaker_) public {
        _angleStaker = angleStaker_;
    }
}
