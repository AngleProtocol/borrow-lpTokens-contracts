// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "borrow-staked/staker/BorrowStaker.sol";

/// @title MockBorrowStaker
/// @author Angle Labs, Inc.
contract MockBorrowStaker is BorrowStaker {
    using SafeERC20 for IERC20;

    error IncompatibleLengths();

    IERC20 public asset_;
    IERC20 public rewardToken;
    uint256 public rewardAmount;

    /// @notice Initializes the `BorrowStaker` for Mock
    function initialize(ICoreBorrow _coreBorrow) external {
        string memory erc20Name = string(
            abi.encodePacked("Angle ", IERC20Metadata(address(asset())).name(), " Mock Staker")
        );
        string memory erc20Symbol = string(abi.encodePacked("agstk-mock-", IERC20Metadata(address(asset())).symbol()));
        _initialize(_coreBorrow, erc20Name, erc20Symbol);
    }

    /// @notice Changes allowance of a set of tokens to addresses
    /// @param tokens Tokens to change allowance for
    /// @param spenders Addresses to approve
    /// @param amounts Approval amounts for each address
    /// @dev You can only change allowance for approved strategies
    function changeAllowance(
        IERC20[] calldata tokens,
        address[] calldata spenders,
        uint256[] calldata amounts
    ) external onlyGovernor {
        if (tokens.length != amounts.length || spenders.length != amounts.length || tokens.length == 0)
            revert IncompatibleLengths();
        for (uint256 i; i < spenders.length; ++i) {
            _changeAllowance(tokens[i], spenders[i], amounts[i]);
        }
    }

    /// @inheritdoc BorrowStaker
    function asset() public view override returns (IERC20) {
        return asset_;
    }

    function setAsset(IERC20 _asset) public {
        asset_ = _asset;
    }

    /// @inheritdoc BorrowStaker
    function _withdrawFromProtocol(uint256 amount) internal override {}

    /// @inheritdoc BorrowStaker
    /// @dev Should be overriden by the implementation if there are more rewards
    function _claimContractRewards() internal virtual override {
        _updateRewards(rewardToken, rewardAmount);
    }

    /// @inheritdoc BorrowStaker
    function _getRewards() internal view override returns (IERC20[] memory rewards) {
        rewards = new IERC20[](1);
        rewards[0] = rewardToken;
        return rewards;
    }

    /// @inheritdoc BorrowStaker
    function _rewardsToBeClaimed(IERC20) internal view override returns (uint256 amount) {
        amount = rewardAmount;
    }

    function setRewardToken(IERC20 token) public {
        rewardToken = token;
    }

    function setRewardAmount(uint256 amount) public {
        rewardAmount = amount;
    }

    function _claimGauges() internal override {}
}

/// @title MockBorrowStakerReset
/// @author Angle Labs, Inc.
contract MockBorrowStakerReset is MockBorrowStaker {
    /// @inheritdoc BorrowStaker
    /// @dev Reset to 0 when rewards are claimed
    function _claimContractRewards() internal virtual override {
        _updateRewards(rewardToken, rewardAmount);
        rewardAmount = 0;
    }
}
