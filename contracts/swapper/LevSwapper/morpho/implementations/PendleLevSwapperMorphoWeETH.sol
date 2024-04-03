// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../PendleLevSwapperMorpho.sol";

/// @author Angle Labs, Inc.
/// @notice Renzo PT ETH leverage swapper
contract PendleLevSwapperMorphoWeETH is PendleLevSwapperMorpho {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter,
        IMorphoBase _morpho
    ) PendleLevSwapperMorpho(_core, _uniV3Router, _oneInch, _angleRouter, _morpho) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function PT() public pure override returns (IERC20) {
        return IERC20(0xc69Ad9baB1dEE23F4605a82b3354F8E40d1E5966);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function SY() public pure override returns (IStandardizedYield) {
        return IStandardizedYield(0xAC0047886a985071476a1186bE89222659970d65);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function YT() public pure override returns (IPYieldTokenV2) {
        return IPYieldTokenV2(0xfb35Fd0095dD1096b1Ca49AD44d8C5812A201677);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function market() public pure override returns (IPMarketV3) {
        return IPMarketV3(0xF32e58F92e60f4b0A37A69b95d642A471365EAe8);
    }

    /// @inheritdoc PendleLevSwapperMorpho
    function collateral() public pure override returns (IERC20) {
        return IERC20(0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee);
    }
}
