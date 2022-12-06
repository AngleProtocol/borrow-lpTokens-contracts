// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../BaseLevSwapper.sol";
import "../../../interfaces/external/balancer/IBalancerVault.sol";

/// @title BalancerStableLevSwapper
/// @author Angle Labs, Inc.
/// @dev Leverage swapper on Balancer Composable Stable Pools LP tokens
/// @dev For more info about Balancer Composable Stable Pools, check:
/// https://docs.balancer.fi/products/balancer-pools/composable-stable-pools#the-lido-wsteth-weth-liquidity-pool
abstract contract BalancerStableLevSwapper is BaseLevSwapper {
    using SafeERC20 for IERC20;

    IBalancerVault public constant BALANCER_VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _oneInch,
        IAngleRouterSidechain _angleRouter
    ) BaseLevSwapper(_core, _uniV3Router, _oneInch, _angleRouter) {
        IAsset[] memory poolTokens = tokens();
        for (uint256 i = 0; i < poolTokens.length; ++i) {
            IERC20(address(poolTokens[i])).safeIncreaseAllowance(address(BALANCER_VAULT), type(uint256).max);
        }
    }

    // =============================== MAIN FUNCTIONS ==============================

    /// @inheritdoc BaseLevSwapper
    function _add(bytes memory) internal override returns (uint256 amountOut) {
        IAsset[] memory poolTokens = tokens();
        // Instead of doing sweeps at the end just use the full balance to add liquidity
        uint256[] memory amounts = new uint256[](poolTokens.length);
        bool nonNullAmount;
        for (uint256 i = 0; i < poolTokens.length; ++i) {
            uint256 amount = IERC20(address(poolTokens[i])).balanceOf(address(this));
            if (amount > 0) nonNullAmount = true;
            amounts[i] = amount;
        }
        // Slippage is checked at the very end of the `swap` function
        if (nonNullAmount)
            BALANCER_VAULT.joinPool(
                poolId(),
                address(this),
                address(this),
                IBalancerVault.JoinPoolRequest(
                    poolTokens,
                    amounts,
                    abi.encode(JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, amounts, 0),
                    false
                )
            );
        amountOut = lpToken().balanceOf(address(this));
    }

    /// @inheritdoc BaseLevSwapper
    function _remove(uint256 burnAmount, bytes memory data) internal override returns (uint256 amountOut) {
        (ExitKind removalType, uint256 tokenIndex) = abi.decode(data, (ExitKind, uint256));
        bytes memory userData;
        if (removalType == ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT)
            userData = abi.encode(removalType, burnAmount, tokenIndex);
        else if (removalType == ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT) userData = abi.encode(removalType, burnAmount);

        IAsset[] memory poolTokens = tokens();
        uint256[] memory amounts = new uint256[](poolTokens.length);
        BALANCER_VAULT.exitPool(
            poolId(),
            address(this),
            payable(address(this)),
            IBalancerVault.ExitPoolRequest(poolTokens, amounts, userData, false)
        );
        return 0;
    }

    // ============================= VIRTUAL FUNCTIONS =============================

    /// @notice Reference to the native `tokens` of the Balancer pool
    function tokens() public pure virtual returns (IAsset[] memory);

    /// @notice ID of the Balancer Pool
    function poolId() public pure virtual returns (bytes32);

    /// @notice Reference to the actual collateral contract
    function lpToken() public pure virtual returns (IERC20);
}
