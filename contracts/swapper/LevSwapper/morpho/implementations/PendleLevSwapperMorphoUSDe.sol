// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/morpho/PendleLevSwapperMorpho.sol";

/// @author Angle Labs, Inc.
/// @notice PT-USDe leverage swapper
contract PendleLevSwapperMorphoUSDe is PendleLevSwapperMorpho {
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
        return IERC20(0xa0021EF8970104c2d008F38D92f115ad56a9B8e1);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function SY() public pure override returns (IStandardizedYield) {
        return IStandardizedYield(0x42862F48eAdE25661558AFE0A630b132038553D0);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function YT() public pure override returns (IPYieldTokenV2) {
        return IPYieldTokenV2(0x1e3d13932C31d7355fCb3FEc680b0cD159dC1A07);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function market() public pure override returns (IPMarketV3) {
        return IPMarketV3(0x19588F29f9402Bb508007FeADd415c875Ee3f19F);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function collateral() public pure override returns (IERC20) {
        return IERC20(0x4c9EDD5852cd905f086C759E8383e09bff1E68B3);
    }
}
