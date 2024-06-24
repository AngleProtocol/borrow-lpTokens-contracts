// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../BaseTest.test.sol";
import "borrow-staked/interfaces/IBorrowStaker.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow-staked/interfaces/external/pendle/IPYieldTokenV2.sol";
import { SwapType, BaseLevSwapper, PendleLevSwapperRenzo, PendleLevSwapper, Swapper, IUniswapV3Router, IAngleRouterSidechain } from "borrow-staked/swapper/LevSwapper/pendle/implementations/PendleLevSwapperRenzo.sol";

contract PendlePTSaverTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    IPYieldTokenV2 internal constant _YT = IPYieldTokenV2(0xF28Db483773E3616DA91FDfa7b5D4090Ac40cC59);
    address internal _PT;
    address internal _SY;
    PendlePTMaturitySaver saver;

    address internal constant _owner = 0x9bEcd6b4Fb076348A455518aea23d3799361FE95;

    function setUp() public override {
        super.setUp();

        _arbitrum = vm.createFork(vm.envString("ETH_NODE_URI_ARBITRUM"), 224238400);
        vm.selectFork(_arbitrum);

        swapper = new PendleLevSwapperRenzo(coreBorrow, _UNI_V3_ROUTER, _ONE_INCH, _ANGLE_ROUTER);
        _PT = YT.PT();
        _SY = YT.SY();

        saver = new PendlePTMaturitySaver(_owner);

        vm.startPrank(_owner);
        _PT.approve(address(saver), type(uint256).max);
        vm.stopPrank();
    }

    function test_Save_Success() public {
        uint256 prevOwnerBalanceSY = _SY.balanceOf(_owner);
        vm.startPrank(_alice);
        saver.recoverYieldBearing(_owner, _YT);
        vm.stopPrank();

        assertEq(_PT.balanceOf(_owner), 0);
        assertEq(_PT.balanceOf(address(_YT)), 0);
        assertEq(_PT.balanceOf(_alice), 0);
        assertGt(_SY.balanceOf(address(saver)), 0);
        assertGe(_SY.balanceOf(_owner), prevOwnerBalanceSY);
        assertEq(_SY.balanceOf(_alice), 0);
    }
}
