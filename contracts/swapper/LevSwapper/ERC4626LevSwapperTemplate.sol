// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/ERC4626LevSwapper.sol";

/// @author Angle Labs, Inc.
/// @notice Template leverage swapper on ERC4626 tokens
contract ERC4626LevSwapperTemplate is ERC4626LevSwapper {
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
        return IERC20(address(0));
    }

    /// @inheritdoc ERC4626LevSwapper
    function token() public pure override returns (IERC4626) {
        return IERC4626(address(0));
    }
}
