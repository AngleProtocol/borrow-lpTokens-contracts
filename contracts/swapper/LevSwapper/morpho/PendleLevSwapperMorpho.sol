// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../BaseLevSwapperMorpho.sol";
import "../../../interfaces/external/pendle/IPMarketV3.sol";
import "../../../interfaces/external/pendle/IStandardizedYield.sol";
import "../../../interfaces/external/pendle/IPYieldTokenV2.sol";
import "../../../interfaces/external/pendle/IPRouter.sol";

/// @title SanTokenLevSwapper
/// @author Angle Labs, Inc.
/// @dev Leverage Swapper on SanTokens
abstract contract PendleLevSwapperMorpho is BaseLevSwapperMorpho {
    using SafeERC20 for IERC20;

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter,
        IMorphoBase _morpho
    ) BaseLevSwapperMorpho(_core, _uniV3Router, _oneInch, _angleRouter, _morpho) {
        if (address(collateral()) != address(0)) {
            collateral().safeIncreaseAllowance(address(SY()), type(uint256).max);
            IERC20(address(SY())).safeIncreaseAllowance(address(pendleRouter()), type(uint256).max);
        }
    }

    // =============================== MAIN FUNCTIONS ==============================

    /// @inheritdoc BaseLevSwapper
    function _add(bytes memory) internal override returns (uint256 amountOut) {
        uint256 amount = collateral().balanceOf(address(this));
        // It needs to be deposited directly onto `YT`contracts to mint both PT and YT tokens
        uint256 amountSharesOut = SY().deposit(address(this), address(collateral()), amount, 0);
        LimitOrderData memory limit;
        (amountOut, ) = pendleRouter().swapExactSyForPt(
            address(this),
            address(market()),
            amountSharesOut,
            0,
            ApproxParams({ guessMin: 0, guessMax: 2 * amountSharesOut, guessOffchain: 0, maxIteration: 10, eps: 1e15 }),
            limit
        );
    }

    /// @inheritdoc BaseLevSwapper
    function _remove(uint256 amount, bytes memory data) internal override {
        uint256 minAmountOut = abi.decode(data, (uint256));
        PT().safeTransfer(address(market()), amount);
        // We send the SY to the contract itself as it needs a non null balance for the redeem
        (uint256 amountSy, ) = market().swapExactPtForSy(address(SY()), amount, hex"");
        SY().redeem(address(this), amountSy, address(collateral()), minAmountOut, true);
    }

    /// @notice Router for simpler swap
    function pendleRouter() public pure returns (IPRouter) {
        return IPRouter(0x00000000005BBB0EF59571E58418F9a4357b68A0);
    }

    // ============================= VIRTUAL FUNCTIONS =============================

    /// @notice Reference to the `Principal Token`
    function PT() public pure virtual returns (IERC20);

    /// @notice Reference to the asset wrapper built by Pendle
    function SY() public pure virtual returns (IStandardizedYield);

    /// @notice Reference to the `Yield Token` contract which distribute only the yield to the holder
    function YT() public pure virtual returns (IPYieldTokenV2);

    /// @notice Reference to the market to swap `collateral` for `YT`
    function market() public pure virtual returns (IPMarketV3);

    /// @notice Reference to the `sanToken` contract which then needs to be staked
    function collateral() public pure virtual returns (IERC20);
}
