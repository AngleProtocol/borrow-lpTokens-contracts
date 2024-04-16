// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/curve/CurveLevSwapper2TokensWithBP.sol";
import { IMetaPool2WithReturn } from "borrow-staked/interfaces/external/curve/IMetaPool2WithReturn.sol";

/// @author Angle Labs, Inc.
/// @dev This implementation is for Curve pools with 2 tokens with one LP token
contract CurveLevSwapperFullLUSDv3CRV is CurveLevSwapper2TokensWithBP {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter
    ) CurveLevSwapper2TokensWithBP(_core, _uniV3Router, _aggregator, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public view virtual override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function tokens() public pure override returns (IERC20[2] memory) {
        return [IERC20(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0), IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490)];
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function indexBPToken() public pure override returns (uint256) {
        return 1;
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function metapool() public pure override returns (IMetaPool2) {
        return IMetaPool2(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function lpToken() public pure override returns (IERC20) {
        return IERC20(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function tokensBP() public pure override returns (IERC20[3] memory) {
        return [
            IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F),
            IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48),
            IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7)
        ];
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function basepool() public pure override returns (IMetaPool3) {
        return IMetaPool3(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    }

    // ================================== OVERRIDE =================================

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function _removeMetaLiquidityOneCoin(
        uint256 burnAmount,
        bytes memory data
    ) internal override returns (uint256 lpTokenBPReceived, bytes memory) {
        int128 whichCoin;
        uint256 minAmountOut;
        (whichCoin, minAmountOut, data) = abi.decode(data, (int128, uint256, bytes));
        minAmountOut = IMetaPool2WithReturn(address(metapool())).remove_liquidity_one_coin(
            burnAmount,
            whichCoin,
            minAmountOut
        );
        // This not true for all pools some may have first the LP token first
        if (whichCoin == int128(int256(indexBPToken()))) lpTokenBPReceived = minAmountOut;
        return (lpTokenBPReceived, data);
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function _removeMetaLiquidityBalance(
        uint256 burnAmount,
        bytes memory data
    ) internal override returns (uint256 lpTokenBPReceived, bytes memory) {
        uint256[2] memory minAmountOuts;
        (minAmountOuts, data) = abi.decode(data, (uint256[2], bytes));
        minAmountOuts = IMetaPool2WithReturn(address(metapool())).remove_liquidity(burnAmount, minAmountOuts);
        lpTokenBPReceived = minAmountOuts[indexBPToken()];
        return (lpTokenBPReceived, data);
    }
}
