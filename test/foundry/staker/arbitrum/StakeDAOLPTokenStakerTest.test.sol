// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../BaseTest.test.sol";
import "../../../../contracts/interfaces/external/convex/IBaseRewardPool.sol";
import "../../../../contracts/interfaces/external/convex/IBooster.sol";
import "../../../../contracts/interfaces/external/convex/IConvexToken.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "../../../../contracts/mock/MockTokenPermit.sol";
import { StakeDAO2PoolStaker, BorrowStakerStorage, IERC20Metadata, IStakeCurveVault, ILiquidityGauge } from "../../../../contracts/staker/curve/implementations/arbitrum/pools/StakeDAO2PoolStaker.sol";

contract StakeDAOLPTokenStakerArbitrumTest is BaseTest {
    using stdStorage for StdStorage;

    address internal _hacker = address(uint160(uint256(keccak256(abi.encodePacked("hacker")))));
    IERC20 private constant _CRV = IERC20(0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978);
    IERC20[] public rewardToken = [_CRV];
    uint256 public constant NBR_REWARD = 1;
    address public constant curveStrategy = 0x2B82FB2B4bac16a1188f377D6a913f235715031b;

    // To be changed
    IERC20 public asset = IERC20(0x7f90122BF0700F9E7e1F688fe926940E8839F353);
    IStakeCurveVault internal constant _vault = IStakeCurveVault(0x0f958528718b625c3aebd305dd2917a37570C56a);
    ILiquidityGauge internal constant _gauge = ILiquidityGauge(0x044f4954937316db6502638065b95E921Fd28475);
    StakeDAO2PoolStaker public stakerImplementation;
    StakeDAO2PoolStaker public staker;

    uint8 public decimalToken;
    uint256 public maxTokenAmount;
    uint8[2] public decimalReward;
    uint256[2] public rewardAmount;

    uint256 public constant WITHDRAW_LENGTH = 10;

    function setUp() public override {
        _arbitrum = vm.createFork(vm.envString("ETH_NODE_URI_ARBITRUM"), 58545851);
        vm.selectFork(_arbitrum);

        super.setUp();
        stakerImplementation = new StakeDAO2PoolStaker();
        staker = StakeDAO2PoolStaker(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.initialize.selector, coreBorrow)
            )
        );
        decimalToken = IERC20Metadata(address(asset)).decimals();
        maxTokenAmount = 10**15 * 10**decimalToken;
        for (uint256 i = 0; i < rewardToken.length; i++) {
            decimalReward[i] = IERC20Metadata(address(rewardToken[i])).decimals();
            rewardAmount[i] = 10**2 * 10**(decimalReward[i]);
        }
    }

    // ============================= DEPOSIT / WITHDRAW ============================

    function testBorrowStakerCurveLP(
        uint256[WITHDRAW_LENGTH] memory amounts,
        uint256[WITHDRAW_LENGTH] memory depositWithdrawRewards,
        uint256[WITHDRAW_LENGTH] memory accounts,
        uint256[WITHDRAW_LENGTH] memory elapseTimes,
        uint256[WITHDRAW_LENGTH * 2] memory rewardAmounts
    ) public {
        amounts[0] = bound(amounts[0], 1, maxTokenAmount);
        deal(address(asset), _alice, amounts[0]);
        vm.startPrank(_alice);
        asset.approve(address(staker), amounts[0]);
        staker.deposit(amounts[0], _alice);
        vm.stopPrank();

        uint256[NBR_REWARD][5] memory pendingRewards;

        for (uint256 i = 0; i < amounts.length; i++) {
            elapseTimes[i] = bound(elapseTimes[i], 1, 180 days);
            vm.warp(block.timestamp + elapseTimes[i]);
            if (depositWithdrawRewards[i] % 3 == 2) {
                uint256[2] memory tmpRewards = [rewardAmounts[i * 2], rewardAmounts[i * 2 + 1]];
                _depositRewards(tmpRewards);
            } else {
                uint256 randomIndex = bound(accounts[i], 0, 3);
                address account = randomIndex == 0 ? _alice : randomIndex == 1 ? _bob : randomIndex == 2
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
                    amount = bound(amounts[i], 1, maxTokenAmount);
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
                    amount = bound(amounts[i], 1, 10**9);
                    staker.withdraw((amount * staker.balanceOf(account)) / 10**9, account, account);
                    for (uint256 j = 0; j < rewardToken.length; j++) {
                        assertEq(staker.pendingRewardsOf(rewardToken[j], account), 0);
                    }
                }
                vm.stopPrank();

                for (uint256 j = 0; j < rewardToken.length; j++) {
                    assertApproxEqAbs(
                        rewardToken[j].balanceOf(account) + staker.pendingRewardsOf(rewardToken[j], account),
                        pendingRewards[randomIndex][j],
                        10**(decimalReward[j] - 4)
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
                        10**(decimalReward[j] - 4)
                    );
                }
            }
        }
    }

    // ================================== INTERNAL =================================

    function _depositRewards(uint256[2] memory amounts) internal {
        amounts[0] = bound(amounts[0], 0, 10_000_000 * 10**(decimalReward[0]));

        deal(address(_CRV), address(curveStrategy), amounts[0]);
        // fake a non null incentives program
        vm.startPrank(address(curveStrategy));
        _CRV.approve(address(_gauge), amounts[0]);
        _gauge.deposit_reward_token(address(_CRV), amounts[0]);
        vm.stopPrank();
    }

    function _rewardsToBeClaimed(IERC20 _rewardToken) internal view returns (uint256 amount) {
        amount = _gauge.claimable_reward(address(staker), address(_rewardToken));
    }
}
