// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../swapper/curve/mainnet/CurveLevSwapper3CRV.test.sol";
import { Convex3CRVStaker } from "../../../../contracts/staker/curve/implementations/mainnet/pools/Convex3CRVStaker.sol";

contract Convex3CRVTest is CurveLevSwapper3CRVTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IERC20 internal constant _BASE_REWARD_POOL = IERC20(0x689440f2Ff927E1f24c72F1087E1FAF471eCe1c8);

    function setUp() public override {
        super.setUp();
        tokenHolder = IERC20(address(_BASE_REWARD_POOL));

        stakerImplementation = MockBorrowStaker(address(new Convex3CRVStaker()));
        staker = MockBorrowStaker(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.initialize.selector, coreBorrow)
            )
        );

        swapper = new MockCurveLevSwapper3CRV(
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
        assertEq(staker.name(), "Angle Curve.fi DAI/USDC/USDT Convex Staker");
        assertEq(staker.symbol(), "agstk-cvx-3Crv");
        assertEq(staker.decimals(), 18);
    }
}
