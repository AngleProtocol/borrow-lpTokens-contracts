// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../CurveLevSwapperFRAXBP.sol";

/// @title StakeDAOLevSwapperFRAXBP
/// @author Angle Labs, Inc.
/// @notice Implements CurveLevSwapperFRAXBP with a StakeDAO staker
contract StakeDAOLevSwapperFRAXBP is CurveLevSwapperFRAXBP {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter
    ) CurveLevSwapperFRAXBP(_core, _uniV3Router, _aggregator, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(0xa9d2Eea75C80fF9669cc998c276Ff26D741Dcb26);
    }
}
