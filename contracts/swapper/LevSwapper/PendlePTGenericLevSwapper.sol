// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/BaseLevSwapperMorpho.sol";
import "borrow-staked/interfaces/external/pendle/IPMarketV3.sol";
import "borrow-staked/interfaces/external/pendle/IStandardizedYield.sol";
import "borrow-staked/interfaces/external/pendle/IPYieldTokenV2.sol";
import "borrow-staked/interfaces/external/pendle/IPRouter.sol";

/// @title PendlePTGenericLevSwapper
/// @author Angle Labs, Inc.
/// @dev Leverage Swapper on Pendle PTs
contract PendlePTGenericLevSwapper is BaseLevSwapperMorpho {
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
        (IERC20 collateral, IStandardizedYield sy, IPMarketV3 market) = abi.decode(
            data,
            (IERC20, IStandardizedYield, IPMarketV3)
        );
        uint256 amount = collateral.balanceOf(address(this));
        // It needs to be deposited directly onto `YT`contracts to mint both PT and YT tokens
        _checkAllowance(collateral, address(sy), amount);
        _checkAllowance(IERC20(address(sy)), address(pendleRouter()), type(uint256).max);
        uint256 amountSharesOut = sy.deposit(address(this), address(collateral), amount, 0);
        LimitOrderData memory limit;
        (amountOut, ) = pendleRouter().swapExactSyForPt(
            address(this),
            address(market),
            amountSharesOut,
            0,
            ApproxParams({ guessMin: 0, guessMax: 2 * amountSharesOut, guessOffchain: 0, maxIteration: 10, eps: 1e18 }),
            limit
        );
    }

    /// @inheritdoc BaseLevSwapper
    function _remove(uint256 amount, bytes memory data) internal override {
        (IERC20 collateral, IStandardizedYield sy, IPMarketV3 market, IERC20 pt, uint256 minAmountOut) = abi.decode(
            data,
            (IERC20, IStandardizedYield, IPMarketV3, IERC20, uint256)
        );
        pt.safeTransfer(address(market), amount);
        // We send the SY to the contract itself as it needs a non null balance for the redeem
        (uint256 amountSy, ) = market.swapExactPtForSy(address(sy), amount, hex"");
        sy.redeem(address(this), amountSy, address(collateral), minAmountOut, true);
    }

    /// @notice Router for simpler swap
    function pendleRouter() public pure returns (IPRouter) {
        return IPRouter(0x00000000005BBB0EF59571E58418F9a4357b68A0);
    }

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }
}
