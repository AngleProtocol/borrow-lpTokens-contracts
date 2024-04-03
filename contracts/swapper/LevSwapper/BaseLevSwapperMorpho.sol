// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import { IMorphoLiquidateCallback } from "morpho-blue/interfaces/IMorphoCallbacks.sol";
import { MarketParams } from "morpho-blue/libraries/MarketParamsLib.sol";
import { IMorphoBase } from "morpho-blue/interfaces/IMorpho.sol";

import "./BaseLevSwapper.sol";

/// @title BaseLevSwapper
/// @author Angle Labs, Inc.
/// @notice Swapper contract facilitating interactions with Angle VaultManager contracts, notably
/// liquidation and leverage transactions
/// @dev This base implementation is for tokens like LP tokens which are not natively supported by 1inch
/// and need some wrapping/unwrapping
abstract contract BaseLevSwapperMorpho is BaseLevSwapper, IMorphoLiquidateCallback {
    using SafeERC20 for IERC20;

    IMorphoBase public morpho;

    error NotTrusted();

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter,
        IMorphoBase _morpho
    ) BaseLevSwapper(_core, _uniV3Router, _oneInch, _angleRouter) {
        morpho = _morpho;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    MORPHO RELATED                                                  
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @dev This function liquidate a position on Morpho Blue via a flashloan
    /// It leverages the previous infrastructure on Angle Borrowing module to liquidate atomically
    function liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        bytes calldata data
    ) external {
        morpho.liquidate(marketParams, borrower, seizedAssets, 0, data);
    }

    function onMorphoLiquidate(uint256 repaidOutToken, bytes calldata data) external {
        if (msg.sender != address(morpho)) revert NotTrusted();
        (IERC20 inToken, IERC20 outToken, uint256 inTokenObtained, bytes memory data) = abi.decode(
            data,
            (IERC20, IERC20, uint256, bytes)
        );

        // Address to receive the surplus amount of token at the end of the call
        address to;
        // For slippage protection, it is checked at the end of the call
        uint256 minAmountOut;
        // Type of the swap to execute: if `swapType == 4`, then it is optional to swap
        uint256 swapType;
        // We're reusing the `data` variable (it can be `path` on UniswapV3, a payload for 1inch or like encoded actions
        // for a router call)
        (to, minAmountOut, swapType, data) = abi.decode(data, (address, uint256, uint256, bytes));

        _swap(inToken, inTokenObtained, SwapType(swapType), data);

        // A final slippage check is performed after the swaps
        uint256 outTokenBalance = outToken.balanceOf(address(this));
        if (outTokenBalance < minAmountOut) revert TooSmallAmountOut();

        outToken.safeApprove(address(morpho), repaidOutToken);
        if (outTokenBalance > repaidOutToken) {
            // The `to` should keep the additional collateral
            outToken.safeTransfer(to, outTokenBalance - repaidOutToken);
        }
        // Reusing the `inTokenObtained` variable for the `inToken` balance
        // Sending back the remaining amount of inTokens to the `to` address: it is possible that not the full `inTokenObtained`
        // is swapped to `outToken` if we're using the `1inch` payload
        inTokenObtained = inToken.balanceOf(address(this));
        if (inTokenObtained != 0) inToken.safeTransfer(to, inTokenObtained);

        // We need to pay back Morpho flashloan
        outToken.safeIncreaseAllowance(address(morpho), repaidOutToken);
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                 GOVERNANCE FUNCTIONS                                               
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @notice Changes morpho endpoint
    function updateMorpho(IMorphoBase _morpho) external {
        if (!core.isGovernorOrGuardian(msg.sender)) revert NotGovernorOrGuardian();
        if (address(_morpho) == address(0) || morpho == _morpho) revert ZeroAddress();
        morpho = _morpho;
    }
}
