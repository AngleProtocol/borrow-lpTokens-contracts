// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../../../swapper/LevSwapper/curve/implementations/mainnet/CurveLevSwapperFullLUSDv3CRV.sol";

/// @title MockCurveLevSwapper2TokensWithBP
/// @author Angle Labs, Inc.
/// @notice Implements a leverage swapper to gain/reduce exposure to the LUSD-3CRV Curve LP token
contract MockCurveLevSwapperFullLUSDv3CRV is CurveLevSwapperFullLUSDv3CRV {
    IBorrowStaker internal _angleStaker;

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter,
        IBorrowStaker angleStaker_
    ) CurveLevSwapperFullLUSDv3CRV(_core, _uniV3Router, _oneInch, _angleRouter) {
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
