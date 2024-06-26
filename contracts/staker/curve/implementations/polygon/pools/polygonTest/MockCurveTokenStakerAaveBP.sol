// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow/interfaces/ILiquidityGauge.sol";
import "borrow-staked/staker/BorrowStaker.sol";

/// @title MockCurveTokenStakerAaveBP
/// @author Angle Labs, Inc.
/// @dev Implements CurveTokenStaker for the Aave BP pool (amDAI - amUSDC - amUSDT)
contract MockCurveTokenStakerAaveBP is BorrowStaker {
    IERC20 private constant _FAKE_REWARD = IERC20(0x02Cb0586F9252626e992B2C6c1B792d9751f2Ede);

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
    function _getRewards() internal pure override returns (IERC20[] memory rewards) {
        rewards = new IERC20[](1);
        rewards[0] = _FAKE_REWARD;
        return rewards;
    }

    /// @inheritdoc BorrowStaker
    function _rewardsToBeClaimed(IERC20 rewardToken) internal view override returns (uint256 amount) {
        amount = liquidityGauge().claimable_reward(address(this), address(rewardToken));
    }

    function asset() public pure override returns (IERC20) {
        return IERC20(0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171);
    }

    function liquidityGauge() public pure returns (ILiquidityGauge) {
        return ILiquidityGauge(0x0f9F2B056Eb2Cc1661fD078F60793F8B0951BDf1);
    }
}
