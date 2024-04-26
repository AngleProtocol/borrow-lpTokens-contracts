// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/morpho/PendleLevSwapperMorpho.sol";

/// @author Angle Labs, Inc.
/// @notice Template leverage swapper on PT tokens
contract PendleLevSwapperTemplate is PendleLevSwapperMorpho {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter,
        IMorphoBase _morpho
    ) PendleLevSwapperMorpho(_core, _uniV3Router, _aggregator, _angleRouter, _morpho) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function PT() public pure override returns (IERC20) {
        return IERC20(address(0));
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function SY() public pure override returns (IStandardizedYield) {
        return IStandardizedYield(address(0));
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function YT() public pure override returns (IPYieldTokenV2) {
        return IPYieldTokenV2(address(0));
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function market() public pure override returns (IPMarketV3) {
        return IPMarketV3(address(0));
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function collateral() public pure override returns (IERC20) {
        return IERC20(address(0));
    }
}
