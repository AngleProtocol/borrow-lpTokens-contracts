// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/BaseLevSwapperMorpho.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title ERC4626LevSwapper
/// @author Angle Labs, Inc.
/// @dev Abstract Leverage Swapper on ERC4626
abstract contract ERC4626LevSwapper is BaseLevSwapperMorpho {
    using SafeERC20 for IERC20;

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter,
        IMorphoBase _morpho
    ) BaseLevSwapperMorpho(_core, _uniV3Router, _aggregator, _angleRouter, _morpho) {
        if (address(asset()) != address(0)) {
            asset().safeIncreaseAllowance(address(token()), type(uint256).max);
        }
    }

    // =============================== MAIN FUNCTIONS ==============================

    /// @inheritdoc BaseLevSwapper
    function _add(bytes memory) internal override returns (uint256 amountOut) {
        uint256 amount = asset().balanceOf(address(this));
        amountOut = token().deposit(amount, address(this));
    }

    /// @inheritdoc BaseLevSwapper
    function _remove(uint256 amount, bytes memory data) internal override {
        uint256 minAmountOut = abi.decode(data, (uint256));
        uint256 amountOut = token().redeem(amount, address(this), address(this));
        // We let this check because the caller may swap part of the tokens received and therefore
        // the check in the base swapper will only be for the out token
        if (amountOut < minAmountOut) revert TooSmallAmountOut();
    }

    // ============================= VIRTUAL FUNCTIONS =============================

    /// @notice Reference to the underlying asset
    function asset() public pure virtual returns (IERC20);

    /// @notice Reference to the erc4626 wrapper
    function token() public pure virtual returns (IERC4626);
}
