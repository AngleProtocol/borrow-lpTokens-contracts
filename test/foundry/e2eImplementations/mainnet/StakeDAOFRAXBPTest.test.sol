// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../swapper/curve/CurveLevSwapper2TokensBaseTest.test.sol";
import { MockCurveLevSwapperFRAXBP } from "../../../../contracts/mock/implementations/swapper/mainnet/MockCurveLevSwapperFRAXBP.sol";
import { StakeDAOFRAXBPStaker, IStakeCurveVault } from "../../../../contracts/staker/curve/implementations/mainnet/StakeDAOFRAXBPStaker.sol";

contract StakeDAOFRAXBPTest is CurveLevSwapper2TokensBaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IERC20 internal constant _STAKEDAO_GAUGE = IERC20(0xBe77585F4159e674767Acf91284160E8C09b96D8);
    IStakeCurveVault internal constant _STAKEDAO_VAULT = IStakeCurveVault(0x11D87d278432Bb2CA6ce175e4a8B4AbDaDE80Fd0);

    function setUp() public override {
        super.setUp();
        tokenHolder = IERC20(address(_STAKEDAO_GAUGE));

        stakerImplementation = MockBorrowStaker(address(new StakeDAOFRAXBPStaker()));
        staker = MockBorrowStaker(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.initialize.selector, coreBorrow)
            )
        );

        swapper = MockCurveLevSwapper2Tokens(
            address(
                new MockCurveLevSwapperFRAXBP(
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
        assertEq(staker.name(), "Angle Curve.fi FRAX/USDC Stake DAO Staker");
        assertEq(staker.symbol(), "agstk-sd-crvFRAX");
        assertEq(staker.decimals(), 18);
    }
}
