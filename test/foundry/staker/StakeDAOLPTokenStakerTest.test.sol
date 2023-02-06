// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../BaseTest.test.sol";
import "../../../contracts/interfaces/external/stakeDAO/IStakeCurveVault.sol";
import "../../../contracts/interfaces/external/stakeDAO/IClaimerRewards.sol";
import "../../../contracts/interfaces/external/stakeDAO/ILiquidityGauge.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "../../../contracts/mock/MockTokenPermit.sol";
import { StakeDAOLUSDv3CRVStaker, BorrowStakerStorage, IERC20Metadata } from "../../../contracts/staker/curve/implementations/mainnet/StakeDAOLUSDv3CRVStaker.sol";

contract StakeDAOLPTokenStakerTest is BaseTest {
    using stdStorage for StdStorage;

    address internal _hacker = address(uint160(uint256(keccak256(abi.encodePacked("hacker")))));
    IERC20 private constant _CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20 private constant _SDT = IERC20(0x73968b9a57c6E53d41345FD57a6E6ae27d6CDB2F);
    IERC20[] public rewardToken = [_CRV, _SDT];
    uint256 public constant NBR_REWARD = 2;
    address public constant sdtDistributor = 0x9C99dffC1De1AfF7E7C1F36fCdD49063A281e18C;
    address public constant curveStrategy = 0x20F1d4Fed24073a9b9d388AfA2735Ac91f079ED6;

    // To be changed
    IERC20 public asset = IERC20(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);
    IStakeCurveVault internal constant _vault = IStakeCurveVault(0xfB5312107c4150c86228e8fd719b8b0Ae2db581d);
    ILiquidityGauge internal constant _gauge = ILiquidityGauge(0x3794C7C69B9c761ede266A9e8B8bb0f6cdf4E3E5);
    StakeDAOLUSDv3CRVStaker public stakerImplementation;
    StakeDAOLUSDv3CRVStaker public staker;

    uint8 public decimalToken;
    uint256 public maxTokenAmount;
    uint8[2] public decimalReward;
    uint256[2] public rewardAmount;

    uint256 public constant WITHDRAW_LENGTH = 10;

    function setUp() public override {
        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 15775969);
        vm.selectFork(_ethereum);

        super.setUp();
        stakerImplementation = new StakeDAOLUSDv3CRVStaker();
        staker = StakeDAOLUSDv3CRVStaker(
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
        amounts[1] = bound(amounts[1], 0, 10_000_000 * 10**(decimalReward[1]));

        deal(address(_CRV), address(curveStrategy), amounts[0]);
        deal(address(_SDT), address(sdtDistributor), amounts[1]);
        // fake a non null incentives program
        vm.startPrank(address(curveStrategy));
        _CRV.approve(address(_gauge), amounts[0]);
        _gauge.deposit_reward_token(address(_CRV), amounts[0]);
        vm.stopPrank();

        vm.startPrank(address(sdtDistributor));
        _SDT.approve(address(_gauge), amounts[1]);
        _gauge.deposit_reward_token(address(_SDT), amounts[1]);
        vm.stopPrank();
    }

    function _rewardsToBeClaimed(IERC20 _rewardToken) internal view returns (uint256 amount) {
        amount = _gauge.claimable_reward(address(staker), address(_rewardToken));
    }
}
