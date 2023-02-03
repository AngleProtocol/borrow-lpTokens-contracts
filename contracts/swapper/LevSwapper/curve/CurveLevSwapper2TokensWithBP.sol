// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../BaseLevSwapper.sol";
import { IMetaPool2 } from "../../../interfaces/external/curve/IMetaPool2.sol";
import { IMetaPool3 } from "../../../interfaces/external/curve/IMetaPool3.sol";

/// @notice All possible removals on Curve
enum CurveRemovalType {
    oneCoin,
    balance,
    imbalance,
    none
}

/// @title CurveLevSwapper3TokensWithBP
/// @author Angle Labs, Inc.
/// @dev Leverage swapper on Curve LP tokens
/// @dev This implementation is for Curve pools with 2 tokens and 1 token is a Curve (3 token) LP token
/// @dev The implementation suppose that the LP `basepool` token is at index 0
abstract contract CurveLevSwapper2TokensWithBP is BaseLevSwapper {
    using SafeERC20 for IERC20;

    uint256 public constant NBR_TOKEN_META = 3;
    uint256 public constant NBR_TOKEN_BP = 3;

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter
    ) BaseLevSwapper(_core, _uniV3Router, _oneInch, _angleRouter) {
        if (address(metapool()) != address(0)) {
            tokens()[0].safeIncreaseAllowance(address(metapool()), type(uint256).max);
            tokens()[1].safeIncreaseAllowance(address(metapool()), type(uint256).max);
            tokensBP()[0].safeIncreaseAllowance(address(basepool()), type(uint256).max);
            tokensBP()[1].safeIncreaseAllowance(address(basepool()), type(uint256).max);
            tokensBP()[2].safeIncreaseAllowance(address(basepool()), type(uint256).max);
        }
    }

    // =============================== MAIN FUNCTIONS ==============================

    /// @inheritdoc BaseLevSwapper
    function _add(bytes memory data) internal override returns (uint256 amountOut) {
        // First, if needed, add liquidity on the base pool to get the BP LP tokens
        bool addOnBP = abi.decode(data, (bool));
        if (addOnBP) {
            // Instead of doing sweeps at the end just use the full balance to add liquidity
            uint256 amountTokenBP1 = tokensBP()[0].balanceOf(address(this));
            uint256 amountTokenBP2 = tokensBP()[1].balanceOf(address(this));
            uint256 amountTokenBP3 = tokensBP()[2].balanceOf(address(this));
            // Slippage is checked at the very end of the `swap` function
            basepool().add_liquidity([amountTokenBP1, amountTokenBP2, amountTokenBP3], 0);
        }
        // Instead of doing sweeps at the end just use the full balance to add liquidity
        uint256 amountToken1 = tokens()[0].balanceOf(address(this));
        uint256 amountToken2 = tokens()[1].balanceOf(address(this));
        // Slippage is checked at the very end of the `swap` function
        if (amountToken1 != 0 || amountToken2 != 0) metapool().add_liquidity([amountToken1, amountToken2], 0);

        // Other solution is also to let the user specify how many tokens have been sent + get
        // the return value from `add_liquidity`: it's more gas efficient but adds more verbose
        amountOut = lpToken().balanceOf(address(this));
    }

    /// @inheritdoc BaseLevSwapper
    /// @dev For some pools `CurveRemovalType.imbalance` may be impossible
    function _remove(uint256 burnAmount, bytes memory data) internal override {
        CurveRemovalType removalType;
        bool swapLPBP;
        (removalType, swapLPBP, data) = abi.decode(data, (CurveRemovalType, bool, bytes));
        uint256 lpTokenBPReceived;
        if (removalType == CurveRemovalType.oneCoin) {
            (lpTokenBPReceived, data) = _removeMetaLiquidityOneCoin(burnAmount, data);
        } else if (removalType == CurveRemovalType.balance) {
            (lpTokenBPReceived, data) = _removeMetaLiquidityBalance(burnAmount, data);
        } else if (removalType == CurveRemovalType.imbalance) {
            address to;
            uint256[2] memory amountOuts;
            (to, amountOuts, data) = abi.decode(data, (address, uint256[2], bytes));
            metapool().remove_liquidity_imbalance(amountOuts, burnAmount);
            lpTokenBPReceived = amountOuts[1];
            uint256 keptAmount = lpToken().balanceOf(address(this));
            // We may have withdrawn more than needed: maybe not optimal because a user may not want to have
            // lp tokens staked. Solution is to do a sweep on all tokens in the `BaseLevSwapper` contract
            if (keptAmount > 0) angleStaker().deposit(keptAmount, to);
        }
        if (swapLPBP) _removeBP(lpTokenBPReceived, data);
    }

    /// @notice Remove liquidity into one coin on `metapool`
    /// @dev It should be overriden if:
    /// - `metapool` return values when removing liquidity as it will be more efficient
    /// - `whichCoin` is not a `int256` but a `int128`
    function _removeMetaLiquidityOneCoin(uint256 burnAmount, bytes memory data)
        internal
        virtual
        returns (uint256 lpTokenBPReceived, bytes memory)
    {
        int128 whichCoin;
        uint256 minAmountOut;
        (whichCoin, minAmountOut, data) = abi.decode(data, (int128, uint256, bytes));
        metapool().remove_liquidity_one_coin(burnAmount, whichCoin, minAmountOut);
        // This not true for all pools some may have first the LP token first
        if (whichCoin == int128(int256(indexBPToken())))
            lpTokenBPReceived = tokens()[indexBPToken()].balanceOf(address(this));
        return (lpTokenBPReceived, data);
    }

    /// @notice Remove liquidity in a balance manner from `metapool`
    /// @dev It should be overriden if `metapool` return values when removing liquidity as it will be more efficient
    function _removeMetaLiquidityBalance(uint256 burnAmount, bytes memory data)
        internal
        virtual
        returns (uint256 lpTokenBPReceived, bytes memory)
    {
        uint256[2] memory minAmountOuts;
        (minAmountOuts, data) = abi.decode(data, (uint256[2], bytes));
        metapool().remove_liquidity(burnAmount, minAmountOuts);
        lpTokenBPReceived = tokens()[indexBPToken()].balanceOf(address(this));
        return (lpTokenBPReceived, data);
    }

    /// @notice Remove liquidity from the `basepool`
    /// @param burnAmount Amount of LP token to burn
    /// @param data External data to process the removal
    function _removeBP(uint256 burnAmount, bytes memory data) internal {
        CurveRemovalType removalType;
        (removalType, data) = abi.decode(data, (CurveRemovalType, bytes));
        if (removalType == CurveRemovalType.oneCoin) {
            (int128 whichCoin, uint256 minAmountOut) = abi.decode(data, (int128, uint256));
            basepool().remove_liquidity_one_coin(burnAmount, whichCoin, minAmountOut);
        } else if (removalType == CurveRemovalType.balance) {
            uint256[3] memory minAmountOuts = abi.decode(data, (uint256[3]));
            basepool().remove_liquidity(burnAmount, minAmountOuts);
        } else if (removalType == CurveRemovalType.imbalance) {
            uint256[3] memory amountOuts = abi.decode(data, (uint256[3]));
            basepool().remove_liquidity_imbalance(amountOuts, burnAmount);
        }
    }

    // ============================= VIRTUAL FUNCTIONS =============================

    /// @notice Reference to the native `tokens` of the Curve pool
    function tokens() public pure virtual returns (IERC20[2] memory);

    /// @notice Index LP token `basepool` in `tokens`
    function indexBPToken() public pure virtual returns (uint256);

    /// @notice Reference to the Curve Pool contract
    function metapool() public pure virtual returns (IMetaPool2);

    /// @notice Reference to the actual collateral contract
    /// @dev Most of the time this is the same address as the `metapool`
    function lpToken() public pure virtual returns (IERC20);

    /// @notice Reference to the native `tokens` of the Curve `basepool`
    function tokensBP() public pure virtual returns (IERC20[3] memory);

    /// @notice Reference to the Curve Pool contract
    function basepool() public pure virtual returns (IMetaPool3);
}
