// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../BaseTest.test.sol";
import "../../../../contracts/interfaces/external/convex/IBaseRewardPool.sol";
import "../../../../contracts/interfaces/external/convex/IBooster.sol";
import "../../../../contracts/interfaces/external/convex/IConvexToken.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "../../../../contracts/mock/MockTokenPermit.sol";
import { AuraSTETHStaker, BorrowStakerStorage, IERC20Metadata, IVirtualBalanceRewardPool } from "../../../../contracts/staker/balancer/implementations/AuraSTETHStaker.sol";

contract AuraLPTokenStakerExtraRewardsTest is BaseTest {
    using stdStorage for StdStorage;

    address internal _hacker = address(uint160(uint256(keccak256(abi.encodePacked("hacker")))));
    IERC20 private constant _BAL = IERC20(0xba100000625a3754423978a60c9317c58a424e3D);
    IERC20 private constant _LDO = IERC20(0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32);
    IConvexToken private constant _AURA = IConvexToken(0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF);
    IERC20 public asset = IERC20(0x32296969Ef14EB0c6d29669C550D4a0449130230);
    IERC20[] public rewardToken = [_BAL, _AURA];
    uint256 public constant NBR_REWARD = 2;
    IConvexBooster public auraBooster = IConvexBooster(0x7818A1DA7BD1E64c199029E86Ba244a9798eEE10);
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
        maxTokenAmount = 10**15 * 10**decimalToken;
    }

    function testBorrowStakerExtraRewards(uint256 amount) public {
        // At the time of the mainnet fork LDO rewards were distributed
        amount = bound(amount, 1, maxTokenAmount);
        deal(address(asset), _alice, amount);
        vm.startPrank(_alice);
        asset.approve(address(staker), amount);
        staker.deposit(amount, _alice);
        vm.warp(block.timestamp + 1 days);
        assertEq(_LDO.balanceOf(_alice) + staker.pendingRewardsOf(_LDO, _alice), 0);
        assertEq(0, staker.claimableRewards(_alice, IERC20(_alice)));
        uint256 functionClaimableRewards = staker.claimableRewards(_alice, _LDO);
        uint256[] memory claimedRewards = staker.claim_rewards(_alice);
        assertEq(functionClaimableRewards, claimedRewards[2]);
        assertEq(_LDO.balanceOf(_alice), functionClaimableRewards);
        vm.stopPrank();
    }
}
