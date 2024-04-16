// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/ERC4626LevSwapper.sol";

/// @author Angle Labs, Inc.
/// @notice Gauntlet USDC Prime Leverage swapper
contract ERC4626LevSwapperMorphoGauntletUSDCPrime is ERC4626LevSwapper {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter,
        IMorphoBase _morpho
    ) ERC4626LevSwapper(_core, _uniV3Router, _aggregator, _angleRouter, _morpho) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }

    /// @inheritdoc ERC4626LevSwapper
    function asset() public pure override returns (IERC20) {
        return IERC20(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48));
    }

    /// @inheritdoc ERC4626LevSwapper
    function token() public pure override returns (IERC4626) {
        return IERC4626(address(0xdd0f28e19C1780eb6396170735D45153D261490d));
    }
}
