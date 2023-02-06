// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../swapper/curve/CurveLevSwapper2TokensWithBPBaseTest.test.sol";
import { ConvexLUSDv3CRVStaker } from "../../../../contracts/staker/curve/implementations/mainnet/ConvexLUSDv3CRVStaker.sol";

contract ConvexLUSDv3CRVTest is CurveLevSwapper2TokensWithBPBaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IERC20 internal constant _BASE_REWARD_POOL = IERC20(0x2ad92A7aE036a038ff02B96c88de868ddf3f8190);

    function setUp() public override {
        super.setUp();
        tokenHolder = IERC20(address(_BASE_REWARD_POOL));

        stakerImplementation = MockBorrowStaker(address(new ConvexLUSDv3CRVStaker()));
        staker = MockBorrowStaker(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.initialize.selector, coreBorrow)
            )
        );

        swapper = new MockCurveLevSwapper2TokensWithBP(
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
        assertEq(staker.name(), "Angle Curve.fi Factory USD Metapool: Liquity Convex Staker");
        assertEq(staker.symbol(), "agstk-cvx-LUSD3CRV-f");
        assertEq(staker.decimals(), 18);
    }
}
