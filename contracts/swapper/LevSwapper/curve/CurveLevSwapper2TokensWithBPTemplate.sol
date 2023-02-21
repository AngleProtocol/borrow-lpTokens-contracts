// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "./CurveLevSwapper2TokensWithBP.sol";

/// @author Angle Labs, Inc.
/// @notice Template leverage swapper on Curve LP tokens
/// @dev This implementation is for Curve pools with 2 tokens with one another Curve pool
contract CurveLevSwapper2TokensWithBPTemplate is CurveLevSwapper2TokensWithBP {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter
    ) CurveLevSwapper2TokensWithBP(_core, _uniV3Router, _oneInch, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function indexBPToken() public pure override returns (uint256) {
        return 0;
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function tokens() public pure override returns (IERC20[2] memory) {
        return [IERC20(address(0)), IERC20(address(0))];
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function metapool() public pure override returns (IMetaPool2) {
        return IMetaPool2(address(0));
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function lpToken() public pure override returns (IERC20) {
        return IERC20(address(0));
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function tokensBP() public pure override returns (IERC20[3] memory) {
        return [IERC20(address(0)), IERC20(address(0)), IERC20(address(0))];
    }

    /// @inheritdoc CurveLevSwapper2TokensWithBP
    function basepool() public pure override returns (IMetaPool3) {
        return IMetaPool3(address(0));
    }
}
