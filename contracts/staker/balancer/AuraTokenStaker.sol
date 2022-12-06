// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../interfaces/external/convex/IBooster.sol";
import "../../interfaces/external/convex/IBaseRewardPool.sol";
import "../../interfaces/external/convex/IConvexToken.sol";
import "../../interfaces/external/curve/ILiquidityGaugeComplete.sol";

import "../BorrowStaker.sol";

/// @title AuraTokenStaker
/// @author Angle Labs, Inc.
/// @dev Borrow staker adapted to Aura LP tokens deposited on the associated liquidity gauge
/// @dev Aura contracts were forked from Convex
abstract contract AuraTokenStaker is BorrowStaker {
    /// @notice Aura-related constants
    IConvexToken private constant _AURA = IConvexToken(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
    IERC20 private constant _BAL = IERC20(0xba100000625a3754423978a60c9317c58a424e3D);
    IConvexBooster private constant _AURA_BOOSTER = IConvexBooster(0x7818A1DA7BD1E64c199029E86Ba244a9798eEE10);

    // ============================= INTERNAL FUNCTIONS ============================

    /// @inheritdoc ERC20Upgradeable
    function _afterTokenTransfer(
        address from,
        address,
        uint256 amount
    ) internal override {
        // Stake on the gauge if it is a deposit
        if (from == address(0)) {
            // Deposit the Balance LP tokens into the Aura contract and stake
            _changeAllowance(asset(), address(_AURA_BOOSTER), amount);
            _AURA_BOOSTER.deposit(poolPid(), amount, true);
        }
    }

    /// @inheritdoc BorrowStaker
    function _withdrawFromProtocol(uint256 amount) internal override {
        baseRewardPool().withdrawAndUnwrap(amount, false);
    }

    /// @inheritdoc BorrowStaker
    function _claimContractRewards() internal virtual override {
        IERC20[] memory rewards = _getRewards();
        uint256 numRewardTokens = rewards.length;
        uint256[] memory claimedBalances = new uint256[](numRewardTokens);
        for (uint256 i; i < numRewardTokens; ++i) {
            claimedBalances[i] = rewards[i].balanceOf(address(this));
        }
        baseRewardPool().getReward(address(this), true);
        for (uint256 i; i < numRewardTokens; ++i) {
            _updateRewards(rewards[i], rewards[i].balanceOf(address(this)) - claimedBalances[i]);
        }
    }

    /// @inheritdoc BorrowStaker
    function _getRewards() internal view override returns (IERC20[] memory rewards) {
        uint256 rewardTokenCount = liquidityGauge().reward_count() + 2;
        rewards = new IERC20[](rewardTokenCount);
        rewards[0] = _BAL;
        rewards[1] = _AURA;
        for (uint256 i = 2; i < rewardTokenCount; i++) {
            rewards[i] = IERC20(liquidityGauge().reward_tokens(i - 2));
        }
    }

    /// @inheritdoc BorrowStaker
    function _rewardsToBeClaimed(IERC20 rewardToken) internal view override returns (uint256 amount) {
        amount = baseRewardPool().earned(address(this));
        if (rewardToken == IERC20(address(_AURA))) {
            // Computation made in the Aura token when claiming rewards check
            uint256 totalSupply = _AURA.totalSupply();
            uint256 cliff = totalSupply / _AURA.reductionPerCliff();
            uint256 totalCliffs = _AURA.totalCliffs();
            if (cliff < totalCliffs) {
                uint256 reduction = totalCliffs - cliff;
                amount = (amount * reduction) / totalCliffs;

                uint256 amtTillMax = _AURA.maxSupply() - totalSupply;
                if (amount > amtTillMax) {
                    amount = amtTillMax;
                }
            }
        }
    }

    // ============================= VIRTUAL FUNCTIONS =============================

    /// @notice ID of the pool associated to the LP token on Aura
    function poolPid() public pure virtual returns (uint256);

    /// @notice Address of the Aura contract on which to claim rewards
    function baseRewardPool() public pure virtual returns (IConvexBaseRewardPool);

    /// @notice Address of the Balancer gauge contract on which to deposit the tokens to get the rewards
    function liquidityGauge() public pure virtual returns (ILiquidityGaugeComplete);
}
