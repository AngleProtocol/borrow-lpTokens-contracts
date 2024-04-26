// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../swapper/curve/arbitrum/CurveLevSwapper2PoolTest.test.sol";
import { MockCurveLevSwapper2Pool } from "borrow-staked/mock/implementations/swapper/arbitrum/MockCurveLevSwapper2Pool.sol";
import { StakeDAO2PoolStaker, IStakeCurveVault } from "borrow-staked/staker/curve/implementations/arbitrum/pools/StakeDAO2PoolStaker.sol";

contract StakeDAO2PoolTest is CurveLevSwapper2PoolTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IStakeCurveVault internal constant _STAKEDAO_VAULT = IStakeCurveVault(0x0f958528718b625c3aebd305dd2917a37570C56a);
    IERC20 internal constant _STAKEDAO_GAUGE = IERC20(0x044f4954937316db6502638065b95E921Fd28475);

    function setUp() public override {
        super.setUp();
        tokenHolder = IERC20(address(_STAKEDAO_GAUGE));

        stakerImplementation = MockBorrowStaker(address(new StakeDAO2PoolStaker()));
        staker = MockBorrowStaker(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.initialize.selector, coreBorrow)
            )
        );

        swapper = new MockCurveLevSwapper2Pool(
            coreBorrow,
            _UNI_V3_ROUTER,
            _ONE_INCH,
            _ANGLE_ROUTER,
            IBorrowStaker(address(staker))
        );

        vm.startPrank(_GOVERNOR);
        IERC20[] memory tokens = new IERC20[](1);
        address[] memory spenders = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = asset;
        spenders[0] = address(staker);
        amounts[0] = type(uint256).max;
        swapper.changeAllowance(tokens, spenders, amounts);
        vm.stopPrank();

        // clear out the token not deposited yet from the strategy
        deal(address(asset), address(_alice), 1);
        vm.startPrank(_alice);
        asset.approve(address(_STAKEDAO_VAULT), 1);
        _STAKEDAO_VAULT.deposit(_alice, 1);
        vm.stopPrank();
    }

    function testInitialise() public override {
        assertEq(staker.name(), "Angle Curve.fi USDC/USDT Stake DAO Staker");
        assertEq(staker.symbol(), "agstk-sd-2CRV");
        assertEq(staker.decimals(), 18);
    }
}
