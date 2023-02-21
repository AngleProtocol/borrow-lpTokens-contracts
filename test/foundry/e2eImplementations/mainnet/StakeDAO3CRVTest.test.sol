// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../swapper/curve/mainnet/CurveLevSwapper3CRV.test.sol";
import { StakeDAO3CRVStaker, IStakeCurveVault } from "../../../../contracts/staker/curve/implementations/mainnet/pools/StakeDAO3CRVStaker.sol";

contract StakeDAO3CRVTest is CurveLevSwapper3CRVTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IERC20 internal constant _STAKEDAO_GAUGE = IERC20(0xf99FD99711671268EE557fEd651EA45e34B2414f);
    IStakeCurveVault internal constant _STAKEDAO_VAULT = IStakeCurveVault(0xb9205784b05fbe5b5298792A24C2CB844B7dc467);

    function setUp() public override {
        super.setUp();
        tokenHolder = IERC20(address(_STAKEDAO_GAUGE));

        stakerImplementation = MockBorrowStaker(address(new StakeDAO3CRVStaker()));
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

        // clear out the token not deposited yet from the strategy
        deal(address(asset), address(_alice), 1);
        vm.startPrank(_alice);
        asset.approve(address(_STAKEDAO_VAULT), 1);
        _STAKEDAO_VAULT.deposit(_alice, 1, true);
        vm.stopPrank();
    }

    function testInitialise() public override {
        assertEq(staker.name(), "Angle Curve.fi DAI/USDC/USDT Stake DAO Staker");
        assertEq(staker.symbol(), "agstk-sd-3Crv");
        assertEq(staker.decimals(), 18);
    }
}
