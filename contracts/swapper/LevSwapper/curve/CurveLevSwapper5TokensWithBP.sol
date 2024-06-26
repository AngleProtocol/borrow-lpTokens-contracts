// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/BaseLevSwapper.sol";
import { ITricrypto3 } from "borrow-staked/interfaces/external/curve/ITricrypto3.sol";
import "borrow-staked/utils/Enums.sol";

/// @title CurveLevSwapper5TokensWithBP
/// @author Angle Labs, Inc.
/// @dev Leverage swapper on Curve LP tokens
/// @dev This implementation is for Curve pools with 5 tokens
abstract contract CurveLevSwapper5TokensWithBP is BaseLevSwapper {
    using SafeERC20 for IERC20;

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter
    ) BaseLevSwapper(_core, _uniV3Router, _aggregator, _angleRouter) {
        if (address(metapool()) != address(0)) {
            tokens()[0].safeIncreaseAllowance(address(metapool()), type(uint256).max);
            tokens()[1].safeIncreaseAllowance(address(metapool()), type(uint256).max);
            tokens()[2].safeIncreaseAllowance(address(metapool()), type(uint256).max);
            tokensBP()[0].safeIncreaseAllowance(address(metapool()), type(uint256).max);
            tokensBP()[1].safeIncreaseAllowance(address(metapool()), type(uint256).max);
            tokensBP()[2].safeIncreaseAllowance(address(metapool()), type(uint256).max);
        }
    }

    // =============================== MAIN FUNCTIONS ==============================

    /// @inheritdoc BaseLevSwapper
    function _add(bytes memory) internal override returns (uint256 amountOut) {
        // Instead of doing sweeps at the end just use the full balance to add liquidity
        uint256 amountToken1 = tokensBP()[0].balanceOf(address(this));
        uint256 amountToken2 = tokensBP()[1].balanceOf(address(this));
        uint256 amountToken3 = tokensBP()[2].balanceOf(address(this));
        uint256 amountToken4 = tokens()[1].balanceOf(address(this));
        uint256 amountToken5 = tokens()[2].balanceOf(address(this));
        // Slippage is checked at the very end of the `swap` function
        if (amountToken1 != 0 || amountToken2 != 0 || amountToken3 != 0 || amountToken4 != 0 || amountToken5 != 0)
            metapool().add_liquidity([amountToken1, amountToken2, amountToken3, amountToken4, amountToken5], 0);
        // Other solution is also to let the user specify how many tokens have been sent + get
        // the return value from `add_liquidity`: it's more gas efficient but adds more verbose
        amountOut = lpToken().balanceOf(address(this));
    }

    /// @inheritdoc BaseLevSwapper
    function _remove(uint256 burnAmount, bytes memory data) internal override {
        CurveRemovalType removalType;
        (removalType, data) = abi.decode(data, (CurveRemovalType, bytes));
        if (removalType == CurveRemovalType.oneCoin) {
            (uint256 whichCoin, uint256 minAmountOut) = abi.decode(data, (uint256, uint256));
            metapool().remove_liquidity_one_coin(burnAmount, whichCoin, minAmountOut);
        } else if (removalType == CurveRemovalType.balance) {
            uint256[5] memory minAmountOuts = abi.decode(data, (uint256[5]));
            metapool().remove_liquidity(burnAmount, minAmountOuts);
        }
    }

    // ============================= VIRTUAL FUNCTIONS =============================

    /// @notice Reference to the native `tokens` of the Curve pool
    function tokens() public pure virtual returns (IERC20[3] memory);

    /// @notice Reference to the Curve Pool contract
    function metapool() public pure virtual returns (ITricrypto3);

    /// @notice Reference to the actual collateral contract
    /// @dev Most of the time this is the same address as the `metapool`
    function lpToken() public pure virtual returns (IERC20);

    /// @notice Reference to the native `tokens` of the Curve `basepool`
    function tokensBP() public pure virtual returns (IERC20[3] memory);
}
