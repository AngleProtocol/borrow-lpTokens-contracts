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

    // ================================= VARIABLES =================================
    ILiquidityGauge public liquidityGauge;

    /// @notice Initializes the `BorrowStaker` for Curve
    function initialize(
        ICoreBorrow _coreBorrow,
        IERC20 _asset,
        ILiquidityGauge _liquidityGauge
    ) external {
        if (address(_liquidityGauge) == address(0)) revert ZeroAddress();
        liquidityGauge = _liquidityGauge;
        string memory erc20Name = string(
            abi.encodePacked("Angle ", IERC20Metadata(address(_asset)).name(), " Curve Staker")
        );
        string memory erc20Symbol = string(abi.encodePacked("agstk-crv-", IERC20Metadata(address(_asset)).symbol()));
        _initialize(_coreBorrow, _asset, erc20Name, erc20Symbol);
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
            ILiquidityGauge _liquidityGauge = liquidityGauge;
            // Deposit the sanTokens into the liquidity gauge contract
            _changeAllowance(asset, address(_liquidityGauge), amount);
            _liquidityGauge.deposit(amount, address(this), false);
        }
    }

    /// @inheritdoc BorrowStaker
    function _withdrawFromProtocol(uint256 amount) internal override {
        liquidityGauge.withdraw(amount, false);
    }

    /// @inheritdoc BorrowStaker
    /// @dev Should be overriden by the implementation if there are more rewards
    function _claimContractRewards() internal virtual override {
        uint256 prevBalanceCRV = _CRV.balanceOf(address(this));
        liquidityGauge.claim_rewards(address(this), address(0));
        uint256 crvRewards = _CRV.balanceOf(address(this)) - prevBalanceCRV;
        // Do the same thing for additional rewards
        _updateRewards(_CRV, crvRewards);
    }

    /// @inheritdoc BorrowStaker
    function _getRewards() internal pure override returns (IERC20[] memory rewards) {
        rewards = new IERC20[](1);
        rewards[0] = _CRV;
        return rewards;
    }

    /// @inheritdoc BorrowStaker
    function _rewardsToBeClaimed(IERC20 rewardToken) internal view override returns (uint256 amount) {
        amount = liquidityGauge.claimable_reward(address(this), address(rewardToken));
    }
}
