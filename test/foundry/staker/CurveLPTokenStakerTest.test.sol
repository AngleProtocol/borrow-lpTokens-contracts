// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../BaseTest.test.sol";
import "borrow-staked/interfaces/external/convex/IBaseRewardPool.sol";
import "borrow-staked/interfaces/external/convex/IBooster.sol";
import "borrow-staked/interfaces/external/convex/IConvexToken.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow-staked/mock/MockTokenPermit.sol";
import { MockCurveStaker3TokensWithBP, BorrowStakerStorage, ILiquidityGauge } from "borrow-staked/mock/MockCurveStaker3TokensWithBP.sol";

interface IMinimalLiquidityGauge {
    // solhint-disable-next-line
    function add_reward(address rewardToken, address distributor) external;
}

contract CurveLPTokenStakerTest is BaseTest {
    using stdStorage for StdStorage;

    address internal _hacker = address(uint160(uint256(keccak256(abi.encodePacked("hacker")))));
    address public CRVDistributor = address(uint160(uint256(keccak256(abi.encodePacked("CRVDistributor")))));

    IERC20 public asset = IERC20(0xdAD97F7713Ae9437fa9249920eC8507e5FbB23d3);
    IERC20 public CRV;
    IERC20 public rewardToken;
    uint256 public constant NBR_REWARD = 1;

    MockCurveStaker3TokensWithBP public stakerImplementation;
    MockCurveStaker3TokensWithBP public staker;
    ILiquidityGauge public gauge;
    uint8 public decimalToken;
    uint256 public minTokenAmount;
    uint256 public maxTokenAmount;
    uint8 public decimalReward;
    uint256 public rewardAmount;

    uint256 public constant WITHDRAW_LENGTH = 3;

    function setUp() public override {
        _polygon = vm.createFork(vm.envString("ETH_NODE_URI_POLYGON"), 35447035);
        vm.selectFork(_ethereum);

        super.setUp();
        stakerImplementation = new MockCurveStaker3TokensWithBP();
        staker = MockCurveStaker3TokensWithBP(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.initialize.selector, coreBorrow)
            )
        );

        gauge = staker.liquidityGauge();

        // CRV rewards are distributed on mainnet not on polygon - fake rewards
        CRV = IERC20(new MockTokenPermit("CRV", "CRV", 18));
        rewardToken = CRV;
        staker.setFakeReward(rewardToken);

        vm.startPrank(0x8A97FBD532A5C1eD67fd67c11dD76013abAc840e);
        IMinimalLiquidityGauge(address(gauge)).add_reward(address(rewardToken), CRVDistributor);
        vm.stopPrank();

        decimalReward = IERC20Metadata(address(rewardToken)).decimals();
        rewardAmount = 10 ** 2 * 10 ** (decimalReward);
        decimalToken = IERC20Metadata(address(asset)).decimals();
        maxTokenAmount = 10 ** 15 * 10 ** decimalToken;
        minTokenAmount = 1;
    }

    // ============================= DEPOSIT / WITHDRAW ============================

    function testCurveBorrowStakerRewards(
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

        uint256[5] memory pendingRewards;

        for (uint256 i; i < amounts.length; ++i) {
            elapseTimes[i] = bound(elapseTimes[i], 1, 180 days);
            vm.warp(block.timestamp + elapseTimes[i]);
            if (depositWithdrawRewards[i] % 3 == 2) {
                _depositRewards(rewardAmount);
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
                    uint256 totSupply = staker.totalSupply();
                    uint256 claimableRewardsFromStaker = gauge.claimable_reward(address(staker), address(rewardToken));
                    if (totSupply > 0) {
                        pendingRewards[0] +=
                            (staker.balanceOf(_alice) * claimableRewardsFromStaker) /
                            staker.totalSupply();
                        pendingRewards[1] +=
                            (staker.balanceOf(_bob) * claimableRewardsFromStaker) /
                            staker.totalSupply();
                        pendingRewards[2] +=
                            (staker.balanceOf(_charlie) * claimableRewardsFromStaker) /
                            staker.totalSupply();
                        pendingRewards[3] +=
                            (staker.balanceOf(_dylan) * claimableRewardsFromStaker) /
                            staker.totalSupply();
                    }
                }

                uint256 amount;
                vm.startPrank(account);
                if (depositWithdrawRewards[i] % 3 == 0) {
                    amount = bound(amounts[i], minTokenAmount, maxTokenAmount);
                    deal(address(asset), account, amount);
                    asset.approve(address(staker), amount);

                    uint256 prevRewardTokenBalance = rewardToken.balanceOf(account);
                    staker.deposit(amount, account);
                    assertEq(rewardToken.balanceOf(account), prevRewardTokenBalance);
                } else {
                    amount = bound(amounts[i], 1, 10 ** 9);
                    amount = (amount * staker.balanceOf(account)) / 10 ** 9;
                    amount = amount == 0 ? staker.balanceOf(account) : amount;
                    staker.withdraw(amount, account, account);
                    assertEq(staker.pendingRewardsOf(rewardToken, account), 0);
                }
                vm.stopPrank();

                assertApproxEqAbs(
                    rewardToken.balanceOf(account) + staker.pendingRewardsOf(rewardToken, account),
                    pendingRewards[randomIndex],
                    10 ** (decimalReward - 4)
                );
            }

            // not working so far I don't know why
            // check on claimable rewards / added the Governor to just have an address with no stake --> should be 0
            address[5] memory allAccounts = [_alice, _bob, _charlie, _dylan, _hacker];
            for (uint256 j = 0; j < allAccounts.length; j++) {
                uint256 prevRewardTokenBalance = rewardToken.balanceOf(allAccounts[j]);
                uint256 functionClaimableRewards = staker.claimableRewards(allAccounts[j], rewardToken);
                uint256[] memory claimedRewards = staker.claim_rewards(allAccounts[j]);
                assertEq(functionClaimableRewards, claimedRewards[0]);
                assertEq(rewardToken.balanceOf(allAccounts[j]) - prevRewardTokenBalance, functionClaimableRewards);
                // Otherwise it has already been taken into account when deposit/withdraw
                if (depositWithdrawRewards[i] % 3 == 2) pendingRewards[j] += functionClaimableRewards;

                assertApproxEqAbs(
                    rewardToken.balanceOf(allAccounts[j]) + staker.pendingRewardsOf(rewardToken, allAccounts[j]),
                    pendingRewards[j],
                    10 ** (decimalReward - 4)
                );
            }
        }
    }

    // ================================== INTERNAL =================================

    function _depositRewards(uint256 amount) internal {
        deal(address(rewardToken), CRVDistributor, amount);
        vm.startPrank(CRVDistributor);
        rewardToken.approve(address(gauge), amount);
        gauge.deposit_reward_token(address(rewardToken), amount);
        vm.stopPrank();
    }
}
