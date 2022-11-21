// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "../../CurveLevSwapper3Tokens.sol";

/// @title CurveLevSwapperTricrypto2
/// @author Angle Labs, Inc
/// @notice Implements a leverage swapper to gain/reduce exposure to the Tricrypto2 Curve LP token
contract CurveLevSwapperTricrypto2 is CurveLevSwapper3Tokens {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter
    ) CurveLevSwapper3Tokens(_core, _uniV3Router, _oneInch, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public view virtual override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }

    /// @inheritdoc CurveLevSwapper3Tokens
    function tokens() public pure override returns (IERC20[3] memory) {
        return [
            IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7),
            IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599),
            IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
        ];
    }

    /// @inheritdoc CurveLevSwapper3Tokens
    function metapool() public pure override returns (IMetaPool3) {
        return IMetaPool3(0xD51a44d3FaE010294C616388b506AcdA1bfAAE46);
    }

    /// @inheritdoc CurveLevSwapper3Tokens
    function lpToken() public pure override returns (IERC20) {
        return IERC20(0xc4AD29ba4B3c580e6D59105FFf484999997675Ff);
    }
}
