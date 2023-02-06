// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../../interfaces/external/convex/IBooster.sol";
import "../../interfaces/external/convex/IBaseRewardPool.sol";
import "../../interfaces/external/convex/IClaimZap.sol";
import "../../interfaces/external/convex/ICvxRewardPool.sol";
import "../../interfaces/external/convex/IConvexToken.sol";

import "../BorrowStaker.sol";

/// @title ConvexTokenStaker
/// @author Angle Labs, Inc.
/// @dev Borrow staker adapted to Curve LP tokens deposited on Convex
abstract contract ConvexTokenStaker is BorrowStaker {
    /// @notice Initializes the `BorrowStaker` for Stake DAO
    function initialize(ICoreBorrow _coreBorrow) external {
        string memory erc20Name = string(
            abi.encodePacked("Angle ", IERC20Metadata(address(asset())).name(), " Convex Staker")
        );
        string memory erc20Symbol = string(abi.encodePacked("agstk-cvx-", IERC20Metadata(address(asset())).symbol()));
        _initialize(_coreBorrow, erc20Name, erc20Symbol);
    }

    // ============================= INTERNAL FUNCTIONS ============================

    /// @inheritdoc ERC20Upgradeable
    function _afterTokenTransfer(
        address from,
        address,
        uint256 amount
    ) internal virtual override {
        // Stake on Convex if it is a deposit
        if (from == address(0)) {
            // Deposit the Curve LP tokens into the convex contract and stake
            _changeAllowance(asset(), address(_convexBooster()), amount);
            _convexBooster().deposit(poolPid(), amount, true);
        }
    }

    /// @inheritdoc BorrowStaker
    function _withdrawFromProtocol(uint256 amount) internal override {
        baseRewardPool().withdrawAndUnwrap(amount, false);
    }

    /// @inheritdoc BorrowStaker
    /// @dev Should be overriden by implementation if there are more rewards
    function _claimGauges() internal virtual override {
        // Claim on Convex
        address[] memory rewardContracts = new address[](1);
        rewardContracts[0] = address(baseRewardPool());
        _convexClaimZap().claimRewards(
            rewardContracts,
            new address[](0),
            new address[](0),
            new address[](0),
            0,
            0,
            0,
            0,
            0
        );
    }

    /// @inheritdoc BorrowStaker
    function _rewardsToBeClaimed(IERC20 rewardToken) internal view override returns (uint256 amount) {
        amount = baseRewardPool().earned(address(this));
        if (rewardToken == IERC20(address(_cvx()))) {
            // Computation made in the Convex token when claiming rewards check
            // https://etherscan.io/address/0x4e3fbd56cd56c3e72c1403e103b45db9da5b9d2b#code
            uint256 totalSupply = _cvx().totalSupply();
            uint256 cliff = totalSupply / _cvx().reductionPerCliff();
            uint256 totalCliffs = _cvx().totalCliffs();
            if (cliff < totalCliffs) {
                uint256 reduction = totalCliffs - cliff;
                amount = (amount * reduction) / totalCliffs;

                uint256 amtTillMax = _cvx().maxSupply() - totalSupply;
                if (amount > amtTillMax) {
                    amount = amtTillMax;
                }
            }
        }
    }

    // ============================= VIRTUAL FUNCTIONS =============================

    /// @notice Address of the Convex contract on which to claim rewards
    function baseRewardPool() public pure virtual returns (IConvexBaseRewardPool);

    /// @notice ID of the pool associated to the LP token on Convex
    function poolPid() public pure virtual returns (uint256);

    /// @notice Address of the Convex contract that routes deposits
    function _convexBooster() internal pure virtual returns (IConvexBooster);

    /// @notice Address of the Convex contract that routes claim rewards
    function _convexClaimZap() internal pure virtual returns (IConvexClaimZap);

    /// @notice Address of the CRV token
    function _crv() internal pure virtual returns (IERC20);

    /// @notice Address of the CVX token
    function _cvx() internal pure virtual returns (IConvexToken);
}
