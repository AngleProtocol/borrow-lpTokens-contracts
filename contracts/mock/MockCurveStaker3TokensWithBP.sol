// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow/interfaces/ILiquidityGauge.sol";
import "borrow-staked/staker/BorrowStaker.sol";

/// @title CurveTokenTricrypto3Staker
/// @author Angle Labs, Inc.
/// @dev Implements CurveTokenStaker for the Tricrypto pool (amUSD - amWBTC - amWETH)
contract MockCurveStaker3TokensWithBP is BorrowStaker {
    /// @notice Curve-related constants
    IERC20 public fakeReward;

    /// @notice Initializes the `BorrowStaker` for Curve
    function initialize(ICoreBorrow _coreBorrow) external {
        string memory erc20Name = string(
            abi.encodePacked("Angle ", IERC20Metadata(address(asset())).name(), " Curve Staker")
        );
        string memory erc20Symbol = string(abi.encodePacked("agstk-crv-", IERC20Metadata(address(asset())).symbol()));
        _initialize(_coreBorrow, erc20Name, erc20Symbol);
    }

    // ============================= INTERNAL FUNCTIONS ============================

    /// @inheritdoc ERC20Upgradeable
    function _afterTokenTransfer(address from, address, uint256 amount) internal override {
        // Stake on the gauge if it is a deposit
        if (from == address(0)) {
            // Deposit the sanTokens into the liquidity gauge contract
            _changeAllowance(asset(), address(liquidityGauge()), amount);
            liquidityGauge().deposit(amount, address(this), false);
        }
    }

    /// @inheritdoc BorrowStaker
    function _withdrawFromProtocol(uint256 amount) internal override {
        liquidityGauge().withdraw(amount, false);
    }

    /// @inheritdoc BorrowStaker
    /// @dev Should be overriden by the implementation if there are more rewards
    function _claimGauges() internal virtual override {
        liquidityGauge().claim_rewards(address(this), address(0));
    }

    /// @inheritdoc BorrowStaker
    function _getRewards() internal view override returns (IERC20[] memory rewards) {
        rewards = new IERC20[](1);
        rewards[0] = fakeReward;
        return rewards;
    }

    /// @inheritdoc BorrowStaker
    function _rewardsToBeClaimed(IERC20 rewardToken) internal view override returns (uint256 amount) {
        amount = liquidityGauge().claimable_reward(address(this), address(rewardToken));
    }

    function setFakeReward(IERC20 _reward) public {
        fakeReward = _reward;
    }

    function asset() public pure override returns (IERC20) {
        return IERC20(0xdAD97F7713Ae9437fa9249920eC8507e5FbB23d3);
    }

    function liquidityGauge() public pure returns (ILiquidityGauge) {
        return ILiquidityGauge(0xCD04f35105c2E696984c512Af3CB37f2b3F354b0);
    }
}
