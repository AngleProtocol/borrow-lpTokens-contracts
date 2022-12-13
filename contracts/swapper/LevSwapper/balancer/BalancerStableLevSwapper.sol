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
        for (uint256 i; i < poolTokens.length; ++i) {
            IERC20(address(poolTokens[i])).safeIncreaseAllowance(address(BALANCER_VAULT), type(uint256).max);
        }
    }

    // =============================== MAIN FUNCTIONS ==============================

    /// @inheritdoc BaseLevSwapper
    /// @dev Inspired from: https://dev.balancer.fi/resources/joins-and-exits/pool-joins#stablepool-joinkinds
    function _add(bytes memory) internal override returns (uint256 amountOut) {
        IAsset[] memory poolTokens = tokens();
        // Instead of doing sweeps at the end just use the full balance to add liquidity
        uint256[] memory amounts = new uint256[](poolTokens.length);
        bool nonNullAmount;
        for (uint256 i; i < poolTokens.length; ++i) {
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
    /// @dev Inspired from: https://dev.balancer.fi/resources/joins-and-exits/pool-exits#stablepool-exitkinds
    function _remove(uint256 burnAmount, bytes memory data) internal override returns (uint256 amountOut) {
        IAsset[] memory poolTokens = tokens();
        uint256[] memory minAmountsOut = new uint256[](poolTokens.length);
        uint256 removalType;
        address to;
        bytes memory extraData;
        (removalType, extraData) = abi.decode(data, (uint256, bytes));
        bytes memory userData;
        if (ExitKind(removalType) == ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT) {
            // There is no need to care for slippage here if the exit is done just in one token because there is a final
            // slippage check performed in the output token
            uint256 exitTokenIndex = abi.decode(extraData, (uint256));
            userData = abi.encode(removalType, burnAmount, exitTokenIndex);
        } else if (ExitKind(removalType) == ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT) {
            // This helps to guarantee that a slippage check is performed not only on the `outToken` if there are multiple
            // tokens out
            minAmountsOut = abi.decode(extraData, (uint256[]));
            userData = abi.encode(removalType, burnAmount);
        } else if (ExitKind(removalType) == ExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT) {
            uint256[] memory amountsOut;
            (amountsOut, to) = abi.decode(extraData, (uint256[], address));
            userData = abi.encode(removalType, amountsOut, burnAmount);
        }
        if (userData.length > 0) {
            BALANCER_VAULT.exitPool(
                poolId(),
                address(this),
                payable(address(this)),
                IBalancerVault.ExitPoolRequest(poolTokens, minAmountsOut, userData, false)
            );
        }
        if (ExitKind(removalType) == ExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT) {
            uint256 leftover = lpToken().balanceOf(address(this));
            if (leftover > 0) angleStaker().deposit(leftover, to);
        }
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
