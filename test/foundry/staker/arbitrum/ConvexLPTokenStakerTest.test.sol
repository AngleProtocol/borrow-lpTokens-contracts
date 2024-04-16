// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../BaseTest.test.sol";
import { IConvexBaseRewardPoolSideChain, EarnedData } from "borrow-staked/interfaces/external/convex/IBaseRewardPool.sol";
import "borrow-staked/interfaces/external/convex/IBooster.sol";
import "borrow-staked/interfaces/external/convex/IConvexToken.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow-staked/mock/MockTokenPermit.sol";
import { Convex2PoolStaker, BorrowStakerStorage, IERC20Metadata } from "borrow-staked/staker/curve/implementations/arbitrum/pools/Convex2PoolStaker.sol";

contract ConvexLPTokenStakerArbitrumTest is BaseTest {
    using stdStorage for StdStorage;

    address internal _hacker = address(uint160(uint256(keccak256(abi.encodePacked("hacker")))));
    IERC20 private _CRV = IERC20(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
    IERC20 private _CVX = IERC20(0xb952A807345991BD529FDded05009F5e80Fe8F45);
    IERC20[] public rewardToken = [_CRV, _CVX];
    uint256 public constant NBR_REWARD = 2;
    IConvexBooster public convexBooster = IConvexBooster(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    // To be changed for different pools
    IERC20 public asset = IERC20(0x7f90122BF0700F9E7e1F688fe926940E8839F353);
    IConvexBaseRewardPoolSideChain public baseRewardPool =
        IConvexBaseRewardPoolSideChain(0x63F00F688086F0109d586501E783e33f2C950e78);
    uint256 public POOL_ID = 1;
    Convex2PoolStaker public stakerImplementation;
    Convex2PoolStaker public staker;

    uint8 public decimalToken;
    uint256 public maxTokenAmount;
    uint256 public minTokenAmount;
    uint8[] public decimalReward;
    uint256[] public rewardAmount;

    uint256 public constant WITHDRAW_LENGTH = 3;

    function setUp() public override {
        super.setUp();

        _arbitrum = vm.createFork(vm.envString("ETH_NODE_URI_ARBITRUM"), 58545851);
        vm.selectFork(_arbitrum);

        stakerImplementation = new Convex2PoolStaker();
        staker = Convex2PoolStaker(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.initialize.selector, coreBorrow)
            )
        );
        decimalToken = IERC20Metadata(address(asset)).decimals();
        maxTokenAmount = 10 ** 5 * 10 ** decimalToken;
        minTokenAmount = 10 ** decimalToken;
        decimalReward = new uint8[](rewardToken.length);
        rewardAmount = new uint256[](rewardToken.length);
        for (uint256 i; i < rewardToken.length; ++i) {
            decimalReward[i] = IERC20Metadata(address(rewardToken[i])).decimals();
            rewardAmount[i] = 10 ** 2 * 10 ** (decimalReward[i]);
        }
    }

    // ============================= DEPOSIT / WITHDRAW ============================

    function testBorrowStakerCurveLP(
        uint256[WITHDRAW_LENGTH] memory amounts,
        uint256[WITHDRAW_LENGTH] memory depositWithdrawRewards,
        uint256[WITHDRAW_LENGTH] memory accounts,
        uint256[WITHDRAW_LENGTH] memory elapseTimes
    ) public {
        amounts[0] = bound(amounts[0], minTokenAmount, maxTokenAmount);
        deal(address(asset), _alice, amounts[0]);
        vm.startPrank(_alice);
        asset.approve(address(staker), amounts[0]);
        staker.deposit(amounts[0], _alice);
        vm.stopPrank();

        uint256[NBR_REWARD][5] memory pendingRewards;

        for (uint256 i; i < amounts.length; ++i) {
            elapseTimes[i] = bound(elapseTimes[i], 1, 180 days);
            vm.warp(block.timestamp + elapseTimes[i]);
            if (depositWithdrawRewards[i] % 3 == 2) {
                _depositRewards(rewardAmount[0], _CRV);
                _depositRewards(rewardAmount[1], _CVX);
            } else {
                uint256 randomIndex = bound(accounts[i], 0, 3);
                address account = randomIndex == 0
                    ? _alice
                    : randomIndex == 1
                        ? _bob
                        : randomIndex == 2
                            ? _charlie
                            : _dylan;
                if (staker.balanceOf(account) == 0) depositWithdrawRewards[i] = 0;

                {
                    for (uint256 j = 0; j < rewardToken.length; j++) {
                        uint256 totSupply = staker.totalSupply();
                        uint256 claimableRewardsFromStaker = _rewardsToBeClaimed(rewardToken[j]);
                        if (totSupply > 0) {
                            pendingRewards[0][j] +=
                                (staker.balanceOf(_alice) * claimableRewardsFromStaker) /
                                staker.totalSupply();
                            pendingRewards[1][j] +=
                                (staker.balanceOf(_bob) * claimableRewardsFromStaker) /
                                staker.totalSupply();
                            pendingRewards[2][j] +=
                                (staker.balanceOf(_charlie) * claimableRewardsFromStaker) /
                                staker.totalSupply();
                            pendingRewards[3][j] +=
                                (staker.balanceOf(_dylan) * claimableRewardsFromStaker) /
                                staker.totalSupply();
                        }
                    }
                }

                uint256 amount;
                vm.startPrank(account);
                if (depositWithdrawRewards[i] % 3 == 0) {
                    amount = bound(amounts[i], minTokenAmount, maxTokenAmount);
                    deal(address(asset), account, amount);
                    asset.approve(address(staker), amount);

                    uint256[] memory prevRewardTokenBalance = new uint256[](rewardToken.length);
                    for (uint256 j = 0; j < rewardToken.length; j++) {
                        prevRewardTokenBalance[j] = rewardToken[j].balanceOf(account);
                    }
                    staker.deposit(amount, account);
                    for (uint256 j = 0; j < rewardToken.length; j++) {
                        assertEq(rewardToken[j].balanceOf(account), prevRewardTokenBalance[j]);
                    }
                } else {
                    amount = bound(amounts[i], 1, 10 ** 9);
                    staker.withdraw((amount * staker.balanceOf(account)) / 10 ** 9, account, account);
                    for (uint256 j = 0; j < rewardToken.length; j++) {
                        assertEq(staker.pendingRewardsOf(rewardToken[j], account), 0);
                    }
                }
                vm.stopPrank();

                for (uint256 j = 0; j < rewardToken.length; j++) {
                    assertApproxEqAbs(
                        rewardToken[j].balanceOf(account) + staker.pendingRewardsOf(rewardToken[j], account),
                        pendingRewards[randomIndex][j],
                        10 ** (decimalReward[j] - 4)
                    );
                }
            }

            // check on claimable rewards / added the Governor to just have an address with no stake --> should be 0
            address[5] memory allAccounts = [_alice, _bob, _charlie, _dylan, _hacker];
            for (uint256 k = 0; k < allAccounts.length; k++) {
                uint256[] memory prevRewardTokenBalance = new uint256[](rewardToken.length);
                uint256[] memory functionClaimableRewards = new uint256[](rewardToken.length);
                for (uint256 j = 0; j < rewardToken.length; j++) {
                    prevRewardTokenBalance[j] = rewardToken[j].balanceOf(allAccounts[k]);
                    functionClaimableRewards[j] = staker.claimableRewards(allAccounts[k], rewardToken[j]);
                }
                uint256[] memory claimedRewards = staker.claim_rewards(allAccounts[k]);
                for (uint256 j = 0; j < rewardToken.length; j++) {
                    assertEq(functionClaimableRewards[j], claimedRewards[j]);
                    assertEq(
                        rewardToken[j].balanceOf(allAccounts[k]) - prevRewardTokenBalance[j],
                        functionClaimableRewards[j]
                    );
                    // Otherwise it has already been taken into account when deposit/withdraw
                    if (depositWithdrawRewards[i] % 3 == 2) pendingRewards[k][j] += functionClaimableRewards[j];

                    assertApproxEqAbs(
                        rewardToken[j].balanceOf(allAccounts[k]) +
                            staker.pendingRewardsOf(rewardToken[j], allAccounts[k]),
                        pendingRewards[k][j],
                        10 ** (decimalReward[j] - 4)
                    );
                }
            }
        }
    }

    // ================================== INTERNAL =================================

    function _depositRewards(uint256 amount, IERC20 token) internal {
        amount = bound(amount, 0, 10_000_000 ether);
        deal(address(token), address(baseRewardPool), token.balanceOf(address(baseRewardPool)) + amount);
        // fake a non null incentives program on Convex
    }

    function _rewardsToBeClaimed(IERC20 _rewardToken) internal returns (uint256 amount) {
        EarnedData[] memory earnings = baseRewardPool.earned(address(staker));
        uint256 earningsLength = earnings.length;
        for (uint256 i; i < earningsLength; ++i)
            if (earnings[i].token == address(_rewardToken)) return earnings[i].amount;
    }
}
