// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../swapper/curve/CurveLevSwapper2TokensWithBPBaseTest.test.sol";
import { MockCurveLevSwapperLUSDv3CRV } from "../../../../contracts/mock/implementations/swapper/mainnet/MockCurveLevSwapperLUSDv3CRV.sol";
import { StakeDAOLUSDv3CRVStaker, IStakeCurveVault } from "../../../../contracts/staker/curve/implementations/mainnet/pools/StakeDAOLUSDv3CRVStaker.sol";

contract StakeDAOLUSDv3CRVTest is CurveLevSwapper2TokensWithBPBaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IERC20 internal constant _STAKEDAO_GAUGE = IERC20(0x3794C7C69B9c761ede266A9e8B8bb0f6cdf4E3E5);
    IStakeCurveVault internal constant _STAKEDAO_VAULT = IStakeCurveVault(0xfB5312107c4150c86228e8fd719b8b0Ae2db581d);

    function setUp() public override {
        super.setUp();
        tokenHolder = IERC20(address(_STAKEDAO_GAUGE));

        stakerImplementation = MockBorrowStaker(address(new StakeDAOLUSDv3CRVStaker()));
        staker = MockBorrowStaker(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.initialize.selector, coreBorrow)
            )
        );

        swapper = MockCurveLevSwapper2TokensWithBP(
            address(
                new MockCurveLevSwapperLUSDv3CRV(
                    coreBorrow,
                    _UNI_V3_ROUTER,
                    _ONE_INCH,
                    _ANGLE_ROUTER,
                    IBorrowStaker(address(staker))
                )
            )
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
        _STAKEDAO_VAULT.deposit(_alice, 1, true);
        vm.stopPrank();
    }

    function testInitialise() public override {
        assertEq(staker.name(), "Angle Curve.fi Factory USD Metapool: Liquity Stake DAO Staker");
        assertEq(staker.symbol(), "agstk-sd-LUSD3CRV-f");
        assertEq(staker.decimals(), 18);
    }
}
