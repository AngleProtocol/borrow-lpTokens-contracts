// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../BaseTest.test.sol";
import "borrow-staked/interfaces/external/convex/IBaseRewardPool.sol";
import "borrow-staked/interfaces/external/convex/IBooster.sol";
import "borrow-staked/interfaces/external/convex/IConvexToken.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow-staked/mock/MockTokenPermit.sol";
import { AuraSTETHStaker, BorrowStakerStorage, IERC20Metadata, IVirtualBalanceRewardPool } from "borrow-staked/staker/balancer/implementations/AuraSTETHStaker.sol";

contract AuraLPTokenStakerExtraRewardsTest is BaseTest {
    using stdStorage for StdStorage;

    address internal _hacker = address(uint160(uint256(keccak256(abi.encodePacked("hacker")))));
    IERC20 private constant _BAL = IERC20(0xba100000625a3754423978a60c9317c58a424e3D);
    IERC20 private constant _LDO = IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32);
    IConvexToken private constant _AURA = IConvexToken(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
    IERC20 public asset = IERC20(0x32296969Ef14EB0c6d29669C550D4a0449130230);
    IERC20[] public rewardToken = [_BAL, _AURA, _LDO];
    uint256 public constant NBR_REWARD = 3;
    IConvexBooster public auraBooster = IConvexBooster(0x7818A1DA7BD1E64c199029E86Ba244a9798eEE10);
    IConvexBaseRewardPool public baseRewardPool = IConvexBaseRewardPool(0xDCee1C640cC270121faF145f231fd8fF1d8d5CD4);
    uint256 public constant POOL_ID = 3;

    AuraSTETHStaker public stakerImplementation;
    AuraSTETHStaker public staker;
    uint8 public decimalToken;
    uint256 public maxTokenAmount;

    uint256 public constant WITHDRAW_LENGTH = 1;

    function setUp() public override {
        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 15124652);
        vm.selectFork(_ethereum);

        super.setUp();
        stakerImplementation = new AuraSTETHStaker();
        staker = AuraSTETHStaker(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.initialize.selector, coreBorrow)
            )
        );
        decimalToken = IERC20Metadata(address(asset)).decimals();
        maxTokenAmount = 10 ** 15 * 10 ** decimalToken;
    }

    function testBorrowStakerExtraRewards(uint256 amount) public {
        // At the time of the mainnet fork LDO rewards were distributed
        amount = bound(amount, 1, maxTokenAmount / 2);
        deal(address(asset), _alice, amount * 2);
        vm.startPrank(_alice);
        asset.approve(address(staker), amount * 2);
        staker.deposit(amount, _alice);
        assertEq(_LDO.balanceOf(_alice) + staker.pendingRewardsOf(_LDO, _alice), 0);
        vm.warp(block.timestamp + 10 days);
        uint256[] memory previousIntegrals = new uint256[](rewardToken.length);
        uint256[] memory toBeClaimed = new uint256[](rewardToken.length);
        uint256 totalSupply = staker.totalSupply();
        for (uint256 j = 0; j < rewardToken.length; j++) {
            previousIntegrals[j] = staker.integral(rewardToken[j]);
            toBeClaimed[j] = _rewardsToBeClaimed(rewardToken[j]);
        }
        staker.deposit(amount, _alice);
        for (uint256 j = 0; j < rewardToken.length; j++) {
            uint256 integral = staker.integral(rewardToken[j]);
            assertEq(integral, previousIntegrals[j] + (toBeClaimed[j] * 10 ** 36) / totalSupply);
            previousIntegrals[j] = integral;
        }
        vm.warp(block.timestamp + 2 days);
        assertEq(0, staker.claimableRewards(_alice, IERC20(_alice)));
        uint256 functionClaimableRewards = staker.claimableRewards(_alice, _LDO);
        totalSupply = staker.totalSupply();
        for (uint256 j = 0; j < rewardToken.length; j++) {
            toBeClaimed[j] = _rewardsToBeClaimed(rewardToken[j]);
        }
        uint256[] memory claimedRewards = staker.claim_rewards(_alice);
        for (uint256 j = 0; j < rewardToken.length; j++) {
            console.log(staker.integral(rewardToken[j]), previousIntegrals[j], toBeClaimed[j]);
            assertEq(staker.integral(rewardToken[j]), previousIntegrals[j] + (toBeClaimed[j] * 10 ** 36) / totalSupply);
        }
        assertEq(functionClaimableRewards, claimedRewards[2]);
        assertEq(_LDO.balanceOf(_alice), functionClaimableRewards);
        vm.stopPrank();
    }

    function _rewardsToBeClaimed(IERC20 _rewardToken) internal view returns (uint256 amount) {
        if (_rewardToken == IERC20(address(_AURA)) || _rewardToken == IERC20(address(_BAL))) {
            amount = baseRewardPool.earned(address(staker));
            if (_rewardToken == IERC20(address(_AURA))) {
                // Computation made in the Aura token when claiming rewards check
                // This computation should also normally take into account a `minterMinted` variable, but this one is private
                // and can therefore not be read on-chain
                uint256 emissionsMinted = _AURA.totalSupply() - 5e25;
                uint256 cliff = emissionsMinted / _AURA.reductionPerCliff();
                uint256 totalCliffs = _AURA.totalCliffs();
                if (cliff < totalCliffs) {
                    uint256 reduction = ((totalCliffs - cliff) * 5) / 2 + 700;
                    amount = (amount * reduction) / totalCliffs;
                    // 5e25 is the emissions max supply
                    uint256 amtTillMax = 5e25 - emissionsMinted;
                    if (amount > amtTillMax) {
                        amount = amtTillMax;
                    }
                }
            }
        } else {
            uint256 rewardTokenLength = baseRewardPool.extraRewardsLength();
            for (uint256 i; i < rewardTokenLength; ++i) {
                IVirtualBalanceRewardPool stakingPool = IVirtualBalanceRewardPool(baseRewardPool.extraRewards(i));
                if (_rewardToken == IERC20(stakingPool.rewardToken())) {
                    amount = stakingPool.earned(address(staker));
                    break;
                }
            }
        }
    }
}
