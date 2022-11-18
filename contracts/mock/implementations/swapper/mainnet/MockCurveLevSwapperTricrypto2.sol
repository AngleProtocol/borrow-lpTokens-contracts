// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "../../../../swapper/LevSwapper/curve/implementations/mainnet/CurveLevSwapperTricrypto2.sol";

/// @title MockCurveLevSwapperTricrypto2
/// @author Angle Labs, Inc.
/// @notice Implement a leverage swapper to gain/reduce exposure to the Tricrypto2 Curve LP token
contract MockCurveLevSwapperTricrypto2 is CurveLevSwapperTricrypto2 {
    IBorrowStaker internal _angleStaker;

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter,
        IBorrowStaker angleStaker_
    ) CurveLevSwapperTricrypto2(_core, _uniV3Router, _oneInch, _angleRouter) {
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
