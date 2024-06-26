// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/curve/CurveLevSwapper3TokensWithBP.sol";

/// @title CurveLevSwapperFRAXBP
/// @author Angle Labs, Inc.
/// @notice Implements a leverage swapper to gain/reduce exposure to the Polygon tricrypto2 Curve LP token
contract CurveLevSwapperTricrypto3 is CurveLevSwapper3TokensWithBP {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter
    ) CurveLevSwapper3TokensWithBP(_core, _uniV3Router, _aggregator, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public view virtual override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }

    /// @inheritdoc CurveLevSwapper3TokensWithBP
    function tokens() public pure override returns (IERC20[3] memory) {
        return [
            // LP token Aave BP Pool
            IERC20(0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171),
            // amWBTC (Aave market)
            IERC20(0x5c2ed810328349100A66B82b78a1791B101C9D61),
            // amWETH (Aave market)
            IERC20(0x28424507fefb6f7f8E9D3860F56504E4e5f5f390)
        ];
    }

    /// @inheritdoc CurveLevSwapper3TokensWithBP
    function indexBPToken() public pure override returns (uint256) {
        return 0;
    }

    /// @inheritdoc CurveLevSwapper3TokensWithBP
    function metapool() public pure override returns (IMetaPool3) {
        return IMetaPool3(0x92215849c439E1f8612b6646060B4E3E5ef822cC);
    }

    /// @inheritdoc CurveLevSwapper3TokensWithBP
    function lpToken() public pure override returns (IERC20) {
        return IERC20(0xdAD97F7713Ae9437fa9249920eC8507e5FbB23d3);
    }

    /// @inheritdoc CurveLevSwapper3TokensWithBP
    function tokensBP() public pure override returns (IERC20[3] memory) {
        return [
            // amDAI (Aave market)
            IERC20(0x27F8D03b3a2196956ED754baDc28D73be8830A6e),
            // amUSDC (Aave market)
            IERC20(0x1a13F4Ca1d028320A707D99520AbFefca3998b7F),
            // amUSDT (Aave market)
            IERC20(0x60D55F02A771d515e077c9C2403a1ef324885CeC)
        ];
    }

    /// @inheritdoc CurveLevSwapper3TokensWithBP
    function basepool() public pure override returns (IMetaPool3) {
        return IMetaPool3(0x445FE580eF8d70FF569aB36e80c647af338db351);
    }
}
