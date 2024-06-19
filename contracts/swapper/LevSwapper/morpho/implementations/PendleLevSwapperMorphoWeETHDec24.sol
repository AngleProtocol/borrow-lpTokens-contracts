// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/morpho/PendleLevSwapperMorpho.sol";

/// @author Angle Labs, Inc.
/// @notice PT weETH leverage swapper with maturity Dec 24
contract PendleLevSwapperMorphoWeETHDec24 is PendleLevSwapperMorpho {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter,
        IMorphoBase _morpho
    ) PendleLevSwapperMorpho(_core, _uniV3Router, _aggregator, _angleRouter, _morpho) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function PT() public pure override returns (IERC20) {
        return IERC20(0x6ee2b5E19ECBa773a352E5B21415Dc419A700d1d);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function SY() public pure override returns (IStandardizedYield) {
        return IStandardizedYield(0xAC0047886a985071476a1186bE89222659970d65);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function YT() public pure override returns (IPYieldTokenV2) {
        return IPYieldTokenV2(0x129e6B5DBC0Ecc12F9e486C5BC9cDF1a6A80bc6A);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function market() public pure override returns (IPMarketV3) {
        return IPMarketV3(0x7d372819240D14fB477f17b964f95F33BeB4c704);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function collateral() public pure override returns (IERC20) {
        return IERC20(0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee);
    }
}
