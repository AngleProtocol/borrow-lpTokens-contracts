// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../CurveLevSwapper2Pool.sol";

/// @title StakeDAOLevSwapper2Pool
/// @author Angle Labs, Inc.
/// @notice Implements CurveLevSwapper2Pool with a StakeDAO staker
contract StakeDAOLevSwapper2Pool is CurveLevSwapper2Pool {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter
    ) CurveLevSwapper2Pool(_core, _uniV3Router, _aggregator, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(0xc8711B1206cD3e89799Ec32973f583e696Cb553C);
    }
}
