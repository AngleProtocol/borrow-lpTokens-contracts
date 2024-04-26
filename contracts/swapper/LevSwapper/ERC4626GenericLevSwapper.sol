// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/BaseLevSwapperMorpho.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

/// @title ERC4626GenericLevSwapper
/// @author Angle Labs, Inc.
/// @dev Leverage Swapper on any ERC4626
contract ERC4626GenericLevSwapper is BaseLevSwapperMorpho {
    using SafeERC20 for IERC20;

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter,
        IMorphoBase _morpho
    ) BaseLevSwapperMorpho(_core, _uniV3Router, _aggregator, _angleRouter, _morpho) {}

    // =============================== MAIN FUNCTIONS ==============================

    /// @inheritdoc BaseLevSwapper
    function _add(bytes memory data) internal override returns (uint256 amountOut) {
        (IERC20 asset, IERC4626 token) = abi.decode(data, (IERC20, IERC4626));
        uint256 amount = asset.balanceOf(address(this));
        _checkAllowance(asset, address(token), amount);
        amountOut = token.deposit(amount, address(this));
    }

    /// @inheritdoc BaseLevSwapper
    function _remove(uint256 amount, bytes memory data) internal override {
        (IERC4626 token, uint256 minAmountOut) = abi.decode(data, (IERC4626, uint256));
        uint256 amountOut = token.redeem(amount, address(this), address(this));
        // We let this check because the caller may swap part of the tokens received and therefore
        // the check in the base swapper will only be for the out token
        if (amountOut < minAmountOut) revert TooSmallAmountOut();
    }

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }
}
