// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "../CurveLevSwapperAaveBP.sol";

/// @title CurveLevSwapperAaveUSDBP
/// @author Angle Labs, Inc.
/// @notice Implement a leverage swapper to gain/reduce exposure to the Polygon Curve AaveBP LP token
/// with a moke staker
contract MockCurveLevSwapperAaveBP is CurveLevSwapperAaveBP {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter
    ) CurveLevSwapperAaveBP(_core, _uniV3Router, _oneInch, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(0xe1Bc17f85d54a81068FC510d5A94E95800D342d9);
    }
}
