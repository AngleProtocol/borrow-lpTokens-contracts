// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../interfaces/external/stakeDAO/IStakeCurveVault.sol";
import "../../interfaces/external/stakeDAO/ILiquidityGauge.sol";

import "../BorrowStaker.sol";

/// @title StakeDAOTokenStaker
/// @author Angle Labs, Inc.
/// @dev Borrow staker adapted to Curve LP tokens deposited on StakeDAO
abstract contract StakeDAOTokenStaker is BorrowStaker {
    IERC20 private constant _CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20 private constant _SDT = IERC20(0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F);

    // =================================== ERRORS ==================================
    error WithdrawFeeTooLarge();

    // ================================= VARIABLES =================================
    IStakeCurveVault public vault;
    ILiquidityGauge public gauge;

    /// @notice Initializes the `BorrowStaker` for Stake DAO
    function initialize(
        ICoreBorrow _coreBorrow,
        IERC20 _asset,
        IStakeCurveVault _vault,
        ILiquidityGauge _gauge
    ) external {
        if (address(_vault) == address(0) || address(_gauge) == address(0)) revert ZeroAddress();
        vault = _vault;
        gauge = _gauge;
        string memory erc20Name = string(
            abi.encodePacked("Angle ", IERC20Metadata(address(_asset)).name(), " Stake DAO Staker")
        );
        string memory erc20Symbol = string(abi.encodePacked("agstk-sd-", IERC20Metadata(address(_asset)).symbol()));
        _initialize(_coreBorrow, _asset, erc20Name, erc20Symbol);
    }

    // ============================= INTERNAL FUNCTIONS ============================

    /// @inheritdoc ERC20Upgradeable
    function _afterTokenTransfer(
        address from,
        address,
        uint256 amount
    ) internal override {
        // Stake on StakeDAO if it is a deposit
        if (from == address(0)) {
            IStakeCurveVault _vault = vault;
            // Approve the vault contract for the Curve LP tokens
            _changeAllowance(asset, address(_vault), amount);
            // Deposit the Curve LP tokens into the vault contract and stake
            _vault.deposit(address(this), amount, true);
        }
    }

    /// @inheritdoc BorrowStaker
    function _withdrawFromProtocol(uint256 amount) internal override {
        IStakeCurveVault _vault = vault;
        uint256 withdrawalFee = _vault.withdrawalFee();
        if (withdrawalFee > 0) revert WithdrawFeeTooLarge();
        _vault.withdraw(amount);
    }

    /// @inheritdoc BorrowStaker
    /// @dev Should be overriden by implementation if there are more rewards
    function _claimContractRewards() internal override {
        uint256 prevBalanceCRV = _CRV.balanceOf(address(this));
        uint256 prevBalanceSDT = _SDT.balanceOf(address(this));

        gauge.claim_rewards(address(this));

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
        amount = gauge.claimable_reward(address(this), address(rewardToken));
    }
}
