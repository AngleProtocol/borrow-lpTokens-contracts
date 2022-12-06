// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../BalancerLevSwapper2StableTokens.sol";

/// @title BalancerLevSwapperWETHWSTETH
/// @author Angle Labs, Inc
/// @notice Implements a leverage swapper to gain/reduce exposure to the Balancer LP WETH/WSTETH LP token
contract BalancerLevSwapperWETHWSTETH is BalancerLevSwapper2StableTokens {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter
    ) BalancerLevSwapper2StableTokens(_core, _uniV3Router, _oneInch, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public view virtual override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }

    /// @inheritdoc BalancerLevSwapper2StableTokens
    function tokens() public pure override returns (IAsset[] memory) {
        IAsset[] memory assets = new IAsset[](2);
        assets[0] = IAsset(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        assets[1] = IAsset(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        return assets;
    }

    /// @inheritdoc BalancerLevSwapper2StableTokens
    function poolId() public pure override returns (bytes32) {
        return bytes32(0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080);
    }

    /// @inheritdoc BalancerLevSwapper2StableTokens
    function lpToken() public pure override returns (IERC20) {
        return IERC20(0x32296969Ef14EB0c6d29669C550D4a0449130230);
    }
}
