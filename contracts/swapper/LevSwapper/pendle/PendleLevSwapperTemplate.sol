// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./PendleLevSwapper.sol";

/// @author Angle Labs, Inc.
/// @notice Template leverage swapper on PT tokens
contract PendleLevSwapperTemplate is PendleLevSwapper {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter
    ) PendleLevSwapper(_core, _uniV3Router, _oneInch, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }

    /// @inheritdoc PendleLevSwapper
    function PT() public pure override returns (IERC20) {
        return IERC20(address(0));
    }

    /// @inheritdoc PendleLevSwapper
    function SY() public pure override returns (IStandardizedYield) {
        return IStandardizedYield(address(0));
    }

    /// @inheritdoc PendleLevSwapper
    function YT() public pure override returns (IPYieldTokenV2) {
        return IPYieldTokenV2(address(0));
    }

    /// @inheritdoc PendleLevSwapper
    function market() public pure override returns (IPMarketV3) {
        return IPMarketV3(address(0));
    }

    /// @inheritdoc PendleLevSwapper
    function collateral() public pure override returns (IERC20) {
        return IERC20(address(0));
    }
}
