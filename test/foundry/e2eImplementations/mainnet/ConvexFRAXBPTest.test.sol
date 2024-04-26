// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../swapper/curve/CurveLevSwapper2TokensBaseTest.test.sol";
import { ConvexFRAXBPStaker } from "borrow-staked/staker/curve/implementations/mainnet/pools/ConvexFRAXBPStaker.sol";

contract ConvexFRAXBPTest is CurveLevSwapper2TokensBaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IERC20 internal constant _BASE_REWARD_POOL = IERC20(0x7e880867363A7e321f5d260Cade2B0Bb2F717B02);

    function setUp() public override {
        super.setUp();
        tokenHolder = IERC20(address(_BASE_REWARD_POOL));

        stakerImplementation = MockBorrowStaker(address(new ConvexFRAXBPStaker()));
        staker = MockBorrowStaker(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.initialize.selector, coreBorrow)
            )
        );

        swapper = new MockCurveLevSwapper2Tokens(
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
        assertEq(staker.name(), "Angle Curve.fi FRAX/USDC Convex Staker");
        assertEq(staker.symbol(), "agstk-cvx-crvFRAX");
        assertEq(staker.decimals(), 18);
    }
}
