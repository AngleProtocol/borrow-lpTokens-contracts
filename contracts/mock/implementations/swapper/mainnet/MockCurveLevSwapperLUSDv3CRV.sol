// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../../../swapper/LevSwapper/curve/implementations/mainnet/CurveLevSwapperLUSDv3CRV.sol";

/// @title MockCurveLevSwapperLUSDv3CRV
/// @author Angle Labs, Inc.
/// @notice Implements a leverage swapper to gain/reduce exposure to the LUSD-3CRV Curve LP token
contract MockCurveLevSwapperLUSDv3CRV is CurveLevSwapperLUSDv3CRV {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter,
        IBorrowStaker angleStaker_
    ) CurveLevSwapperLUSDv3CRV(_core, _uniV3Router, _oneInch, _angleRouter, angleStaker_) {}

    function setAngleStaker(IBorrowStaker angleStaker_) public {
        _angleStaker = angleStaker_;
    }
}
