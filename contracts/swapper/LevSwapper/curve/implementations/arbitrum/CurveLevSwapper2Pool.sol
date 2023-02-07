// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../CurveLevSwapper2Tokens.sol";

/// @title CurveLevSwapper2Pool
/// @author Angle Labs, Inc
/// @notice Implements a leverage swapper to gain/reduce exposure to the 2Pool Curve LP token
contract CurveLevSwapper2Pool is CurveLevSwapper2Tokens {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter
    ) CurveLevSwapper2Tokens(_core, _uniV3Router, _oneInch, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public view virtual override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }

    /// @inheritdoc CurveLevSwapper2Tokens
    function tokens() public pure override returns (IERC20[2] memory) {
        return [IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8), IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9)];
    }

    /// @inheritdoc CurveLevSwapper2Tokens
    function metapool() public pure override returns (IMetaPool2) {
        return IMetaPool2(0x7f90122BF0700F9E7e1F688fe926940E8839F353);
    }

    /// @inheritdoc CurveLevSwapper2Tokens
    function lpToken() public pure override returns (IERC20) {
        return IERC20(0x7f90122BF0700F9E7e1F688fe926940E8839F353);
    }
}
