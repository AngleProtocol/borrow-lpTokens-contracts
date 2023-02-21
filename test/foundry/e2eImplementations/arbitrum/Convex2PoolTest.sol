// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "../../swapper/curve/arbitrum/CurveLevSwapper2PoolTest.test.sol";
import { Convex2PoolStaker } from "../../../../contracts/staker/curve/implementations/arbitrum/pools/Convex2PoolStaker.sol";

contract Convex2PoolTest is CurveLevSwapper2PoolTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IERC20 internal constant _BASE_REWARD_POOL = IERC20(0x63F00F688086F0109d586501E783e33f2C950e78);

    function setUp() public override {
        super.setUp();
        tokenHolder = IERC20(address(_BASE_REWARD_POOL));

        stakerImplementation = MockBorrowStaker(address(new Convex2PoolStaker()));
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
    }

    function testInitialise() public override {
        assertEq(staker.name(), "Angle Curve.fi USDC/USDT Convex Staker");
        assertEq(staker.symbol(), "agstk-cvx-2CRV");
        assertEq(staker.decimals(), 18);
    }
}
