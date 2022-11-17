// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import "../../interfaces/external/stakeDAO/IStakeCurveVault.sol";
import "../../interfaces/external/stakeDAO/IClaimerRewards.sol";
import "../../interfaces/external/stakeDAO/ILiquidityGauge.sol";

import "../BorrowStaker.sol";

/// @title ConvexTokenStaker
/// @author Angle Labs, Inc.
/// @dev Borrow staker adapted to Curve LP tokens deposited on Convex
abstract contract StakeDAOTokenStaker is BorrowStaker {
    IERC20 private constant _CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20 private constant _SDT = IERC20(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B);

    error WithdrawFeeTooLarge();

    // ============================= INTERNAL FUNCTIONS ============================

    /// @inheritdoc ERC20Upgradeable
    function _afterTokenTransfer(
        address from,
        address,
        uint256 amount
    ) internal override {
        // Stake on Convex if it is a deposit
        if (from == address(0)) {
            // Approve the vault contract for the Curve LP tokens
            _changeAllowance(asset(), address(_vault()), amount);
            // Deposit the Curve LP tokens into the vault contract and stake
            _vault().deposit(address(this), amount, true);
        }
    }

    /// @inheritdoc BorrowStaker
    function _withdrawFromProtocol(uint256 amount) internal override {
        uint256 withdrawalFee = _vault().withdrawalFee();
        if (withdrawalFee > 0) revert WithdrawFeeTooLarge();
        _vault().withdraw(amount);
    }

    /// @inheritdoc BorrowStaker
    /// @dev Should be overriden by implementation if there are more rewards
    function _claimRewards() internal override {
        uint256 prevBalanceCRV = _CRV.balanceOf(address(this));
        uint256 prevBalanceSDT = _SDT.balanceOf(address(this));

        _gauge().claim_rewards(address(this));

        uint256 crvRewards = _CRV.balanceOf(address(this)) - prevBalanceCRV;
        uint256 sdtRewards = _SDT.balanceOf(address(this)) - prevBalanceSDT;

        // do the same thing for additional rewards
        _updateRewards(_CRV, crvRewards);
        _updateRewards(_SDT, sdtRewards);
    }

    /// @inheritdoc BorrowStaker
    function _getRewards() internal pure override returns (IERC20[] memory rewards) {
        rewards = new IERC20[](2);
        rewards[0] = _CRV;
        rewards[1] = _SDT;
        return rewards;
    }

    /// @inheritdoc BorrowStaker
    function _rewardsToBeClaimed(IERC20 rewardToken) internal view override returns (uint256 amount) {
        amount = _gauge().claimable_reward(address(this), address(rewardToken));
    }

    // ============================= VIRTUAL FUNCTIONS =============================
    /// @notice StakeDAO Vault address
    function _vault() internal pure virtual returns (IStakeCurveVault);

    /// @notice StakeDAO Gauge address
    function _gauge() internal pure virtual returns (ILiquidityGauge);
}
