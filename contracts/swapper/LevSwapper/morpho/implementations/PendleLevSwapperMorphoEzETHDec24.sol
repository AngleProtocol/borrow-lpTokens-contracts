// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/morpho/PendleLevSwapperMorpho.sol";

/// @author Angle Labs, Inc.
/// @notice PT ezETH leverage swapper with maturity Dec 24
contract PendleLevSwapperMorphoEzETHDec24 is PendleLevSwapperMorpho {
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
        return IERC20(0xf7906F274c174A52d444175729E3fa98f9bde285);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function SY() public pure override returns (IStandardizedYield) {
        return IStandardizedYield(0x22E12A50e3ca49FB183074235cB1db84Fe4C716D);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function YT() public pure override returns (IPYieldTokenV2) {
        return IPYieldTokenV2(0x7749F5Ed1e356EDc63D469c2fcaC9adEB56d1C2b);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function market() public pure override returns (IPMarketV3) {
        return IPMarketV3(0xD8F12bCDE578c653014F27379a6114F67F0e445f);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function collateral() public pure override returns (IERC20) {
        return IERC20(0xbf5495Efe5DB9ce00f80364C8B423567e58d2110);
    }
}
