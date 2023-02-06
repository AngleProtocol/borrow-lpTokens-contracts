// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow/interfaces/ILiquidityGauge.sol";

import "../BorrowStaker.sol";

/// @title CurveTokenStaker
/// @author Angle Labs, Inc.
/// @dev Borrow staker adapted to Curve LP token deposited on the liquidity gauge associated
abstract contract CurveTokenStaker is BorrowStaker {
    /// @notice Curve-related constants
    IERC20 private constant _CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);

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
    function _afterTokenTransfer(
        address from,
        address,
        uint256 amount
    ) internal override {
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
    function _rewardsToBeClaimed(IERC20 rewardToken) internal view override returns (uint256 amount) {
        amount = liquidityGauge().claimable_reward(address(this), address(rewardToken));
    }

    // ============================= VIRTUAL FUNCTIONS =============================

    /// @notice Address of the liquidity gauge contract on which to deposit the tokens to get the rewards
    function liquidityGauge() public view virtual returns (ILiquidityGauge);
}
