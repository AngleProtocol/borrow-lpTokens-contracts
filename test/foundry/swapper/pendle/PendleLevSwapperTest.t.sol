// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../BaseTest.test.sol";
import "../../../../contracts/interfaces/IBorrowStaker.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "../../../../contracts/mock/MockTokenPermit.sol";
import { SwapType, BaseLevSwapper, PendleLevSwapperRenzo, PendleLevSwapper, Swapper, IUniswapV3Router, IAngleRouterSidechain } from "../../../../contracts/swapper/LevSwapper/pendle/implementations/PendleLevSwapperRenzo.sol";

contract PendleLevSwapperTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    address internal constant _ONE_INCH = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
    IUniswapV3Router internal constant _UNI_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAngleRouterSidechain internal constant _ANGLE_ROUTER =
        IAngleRouterSidechain(address(uint160(uint256(keccak256(abi.encodePacked("_fakeAngleRouter"))))));

    uint256 internal constant _BPS = 10000;
    PendleLevSwapper public swapper;
    IERC20 public asset;
    IERC20 public collateral;

    uint256 public constant DEPOSIT_LENGTH = 10;
    uint256 public constant WITHDRAW_LENGTH = 10;

    function setUp() public override {
        super.setUp();

        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_ARBITRUM"), 19413820);
        vm.selectFork(_ethereum);

        // reset coreBorrow because the `makePersistent()` doens't work on my end
        coreBorrow = new MockCoreBorrow();
        coreBorrow.toggleGuardian(_GUARDIAN);
        coreBorrow.toggleGovernor(_GOVERNOR);

        swapper = new PendleLevSwapperRenzo(coreBorrow, _UNI_V3_ROUTER, _ONE_INCH, _ANGLE_ROUTER);
        asset = swapper.PT();
        collateral = swapper.collateral();

        vm.startPrank(_alice);
        asset.approve(address(swapper), type(uint256).max);
        collateral.approve(address(swapper), type(uint256).max);
        vm.stopPrank();
    }

    // function testLeverageNoUnderlyingTokenDeposited(uint256 amount) public {
    //     amount = bound(amount, 10 ** 15, 10 ** 20);

    //     deal(address(asset), address(_alice), amount);
    //     vm.startPrank(_alice);
    //     // intermediary variables
    //     bytes[] memory oneInchData = new bytes[](0);

    //     uint256 minAmountOut = amount;
    //     bytes memory addData;
    //     bytes memory swapData = abi.encode(oneInchData, addData);
    //     bytes memory leverageData = abi.encode(true, _alice, swapData);
    //     bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

    //     // we first need to send the tokens before hand, you should always use the swapper
    //     // in another tx to not losse your funds by front running
    //     asset.transfer(address(swapper), amount);
    //     swapper.swap(IERC20(address(_USDC)), IERC20(address(staker)), _alice, 0, amount, data);

    //     vm.stopPrank();

    //     assertGe(staker.balanceOf(_alice), minAmountOut);
    //     assertEq(staker.balanceOf(_alice), staker.totalSupply());
    //     assertEq(asset.balanceOf(_alice), 0);
    //     assertEq(staker.balanceOf(address(swapper)), 0);
    //     assertEq(asset.balanceOf(address(swapper)), 0);
    //     assertGe(asset.balanceOf(address(staker)), minAmountOut);
    //     assertEq(_FRAX.balanceOf(_alice), 0);
    //     assertEq(_USDT.balanceOf(_alice), 0);
    //     assertEq(_FRAX.balanceOf(address(swapper)), 0);
    //     assertEq(_USDT.balanceOf(address(swapper)), 0);
    //     assertEq(_FRAX.balanceOf(address(staker)), 0);
    //     assertEq(_USDT.balanceOf(address(staker)), 0);
    // }

    function testLeverageSuccess(uint256 amount) public {
        amount = bound(amount, 10 ** 15, 10 ** 20);

        deal(address(collateral), address(_alice), amount);
        vm.startPrank(_alice);
        // intermediary variables
        bytes[] memory oneInchData = new bytes[](0);

        uint256 minAmountOut = amount / 2;
        bytes memory addData;
        bytes memory swapData = abi.encode(oneInchData, addData);
        bytes memory leverageData = abi.encode(true, _alice, swapData);
        bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

        // we first need to send the tokens before hand, you should always use the swapper
        // in another tx to not loose your funds by front running
        collateral.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(collateral)), IERC20(address(asset)), _alice, 0, amount, data);

        vm.stopPrank();

        assertEq(collateral.balanceOf(_alice), 0);
        assertEq(collateral.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(address(swapper)), 0);
        assertGe(asset.balanceOf(_alice), minAmountOut);
    }

    // function testLeverageSuccess(uint256 amount) public {
    //     uint256 amountFRAX = 10000 ether;
    //     uint256 amountUSDT = 10000 * 10 ** 6;
    //     amount = bound(amount, 0, 10 ** 15);

    //     deal(address(_USDC), address(_alice), amount);
    //     deal(address(_USDT), address(_alice), amountUSDT);
    //     deal(address(_FRAX), address(_alice), amountFRAX);
    //     vm.startPrank(_alice);
    //     // intermediary variables
    //     bytes[] memory oneInchData = new bytes[](2);
    //     // swap 10000 FRAX for USDC
    //     oneInchData[0] = abi.encode(
    //         address(_FRAX),
    //         0,
    //         hex"e449022e00000000000000000000000000000000000000000000021e19e0c9bab2400000000000000000000000000000000000000000000000000000000000024dc9bbaa000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000009a834b70c07c81a9fcd6f22e842bf002fbffbe4dcfee7c08"
    //     );
    //     // swap 10000 USDT for USDC
    //     oneInchData[1] = abi.encode(
    //         address(_USDT),
    //         0,
    //         hex"e449022e00000000000000000000000000000000000000000000000000000002540be400000000000000000000000000000000000000000000000000000000024e089f88000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000018000000000000000000000003416cf6c708da44db2624d63ea0aaef7113527c6cfee7c08"
    //     );

    //     (, , , , , uint256 sanRate, , , ) = _STABLE_MASTER.collateralMap(address(_POOL_MANAGER));
    //     uint256 minAmountOut = ((((amount + amountUSDT + amountFRAX / _DECIMAL_NORM_USDC) * 9900) / _BPS) * 10 ** 18) /
    //         sanRate;

    //     bytes memory addData;
    //     bytes memory swapData = abi.encode(oneInchData, addData);
    //     bytes memory leverageData = abi.encode(true, _alice, swapData);
    //     bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

    //     // we first need to send the tokens before hand, you should always use the swapper
    //     // in another tx to not losse your funds by front running
    //     _USDC.transfer(address(swapper), amount);
    //     _FRAX.transfer(address(swapper), amountFRAX);
    //     _USDT.safeTransfer(address(swapper), amountUSDT);
    //     swapper.swap(IERC20(address(_USDC)), IERC20(address(staker)), _alice, 0, amount, data);

    //     vm.stopPrank();

    //     assertGt(staker.balanceOf(_alice), minAmountOut);
    //     assertEq(staker.balanceOf(_alice), staker.totalSupply());
    //     assertEq(asset.balanceOf(_alice), 0);
    //     assertEq(staker.balanceOf(address(swapper)), 0);
    //     assertEq(asset.balanceOf(address(swapper)), 0);
    //     assertGt(asset.balanceOf(address(staker)), minAmountOut);
    //     assertEq(_FRAX.balanceOf(_alice), 0);
    //     assertEq(_USDT.balanceOf(_alice), 0);
    //     assertEq(_FRAX.balanceOf(address(swapper)), 0);
    //     assertEq(_USDT.balanceOf(address(swapper)), 0);
    //     assertEq(_FRAX.balanceOf(address(staker)), 0);
    //     assertEq(_USDT.balanceOf(address(staker)), 0);
    // }

    // function testRevertSlippageDeleverage(uint256 amount, uint256 newSanRate) public {
    //     uint256 amountFRAX = 10000 ether;
    //     uint256 amountUSDT = 10000 * 10 ** 6;
    //     amount = bound(amount, 0, 10 ** 15);

    //     deal(address(_USDC), address(_alice), amount);
    //     deal(address(_USDT), address(_alice), amountUSDT);
    //     deal(address(_FRAX), address(_alice), amountFRAX);
    //     vm.startPrank(_alice);

    //     bytes memory data;
    //     uint256 minAmountOut;
    //     {
    //         // intermediary variables
    //         bytes[] memory oneInchData = new bytes[](2);
    //         // swap 10000 FRAX for USDC
    //         oneInchData[0] = abi.encode(
    //             address(_FRAX),
    //             0,
    //             hex"e449022e00000000000000000000000000000000000000000000021e19e0c9bab2400000000000000000000000000000000000000000000000000000000000024dc9bbaa000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000009a834b70c07c81a9fcd6f22e842bf002fbffbe4dcfee7c08"
    //         );
    //         // swap 10000 USDT for USDC
    //         oneInchData[1] = abi.encode(
    //             address(_USDT),
    //             0,
    //             hex"e449022e00000000000000000000000000000000000000000000000000000002540be400000000000000000000000000000000000000000000000000000000024e089f88000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000018000000000000000000000003416cf6c708da44db2624d63ea0aaef7113527c6cfee7c08"
    //         );

    //         (, , , , , uint256 sanRate, , , ) = _STABLE_MASTER.collateralMap(address(_POOL_MANAGER));
    //         minAmountOut =
    //             ((((amount + amountUSDT + amountFRAX / _DECIMAL_NORM_USDC) * 9900) / _BPS) * 10 ** 18) /
    //             sanRate;

    //         bytes memory addData;
    //         bytes memory swapData = abi.encode(oneInchData, addData);
    //         bytes memory leverageData = abi.encode(true, _alice, swapData);
    //         data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);
    //     }

    //     // we first need to send the tokens before hand, you should always use the swapper
    //     // in another tx to not losse your funds by front running
    //     _USDC.transfer(address(swapper), amount);
    //     _FRAX.transfer(address(swapper), amountFRAX);
    //     _USDT.safeTransfer(address(swapper), amountUSDT);
    //     swapper.swap(IERC20(address(_USDC)), IERC20(address(staker)), _alice, 0, amount, data);

    //     // change the sanRate and mint USDC on the poolManager in case sanRate increase
    //     newSanRate = bound(newSanRate, 0, 1_000_000 ether);
    //     deal(address(_USDC), address(_POOL_MANAGER), type(uint256).max);
    //     stdstore
    //         .target(address(_STABLE_MASTER))
    //         .sig("collateralMap(address)")
    //         .with_key(address(_POOL_MANAGER))
    //         .depth(5)
    //         .checked_write(newSanRate);

    //     // deleverage
    //     uint256 swapMinAmountOut;
    //     amount = staker.balanceOf(_alice);
    //     uint256 netAmount = (amount * newSanRate) / 10 ** 18;
    //     if (netAmount > 19000 * 10 ** 6) {
    //         minAmountOut = (((netAmount - 19000 * 10 ** 6) * 9900) / _BPS);
    //         swapMinAmountOut = (19000 ether * 9900) / _BPS;
    //     } else minAmountOut = netAmount;

    //     {
    //         bytes[] memory oneInchData;
    //         // If there isn't enough to do the swap don't do it
    //         if (netAmount > 19000 * 10 ** 6) {
    //             oneInchData = new bytes[](1);
    //             // swap 19000 USDC for FRAX
    //             oneInchData[0] = abi.encode(
    //                 address(_USDC),
    //                 swapMinAmountOut,
    //                 hex"e449022e000000000000000000000000000000000000000000000000000000046c7cfe000000000000000000000000000000000000000000000003fbfd1ac7f9631196a0000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000018000000000000000000000009a834b70c07c81a9fcd6f22e842bf002fbffbe4dcfee7c08"
    //             );
    //         } else {
    //             oneInchData = new bytes[](0);
    //         }
    //         IERC20[] memory sweepTokens = new IERC20[](1);
    //         sweepTokens[0] = _USDC;
    //         bytes memory removeData = abi.encode(netAmount + 1);
    //         bytes memory swapData = abi.encode(amount, amount, sweepTokens, oneInchData, removeData);
    //         bytes memory leverageData = abi.encode(false, _alice, swapData);
    //         data = abi.encode(address(0), swapMinAmountOut, SwapType.Leverage, leverageData);
    //     }
    //     staker.transfer(address(swapper), amount);
    //     vm.expectRevert(Swapper.TooSmallAmountOut.selector);
    //     swapper.swap(IERC20(address(staker)), IERC20(address(_FRAX)), _alice, 0, amount, data);
    //     vm.stopPrank();
    // }

    // function testDeleverage(uint256 amount, uint256 newSanRate) public {
    //     uint256 amountFRAX = 10000 ether;
    //     uint256 amountUSDT = 10000 * 10 ** 6;
    //     amount = bound(amount, 0, 10 ** 15);

    //     deal(address(_USDC), address(_alice), amount);
    //     deal(address(_USDT), address(_alice), amountUSDT);
    //     deal(address(_FRAX), address(_alice), amountFRAX);
    //     vm.startPrank(_alice);

    //     bytes memory data;
    //     uint256 minAmountOut;
    //     {
    //         // intermediary variables
    //         bytes[] memory oneInchData = new bytes[](2);
    //         // swap 10000 FRAX for USDC
    //         oneInchData[0] = abi.encode(
    //             address(_FRAX),
    //             0,
    //             hex"e449022e00000000000000000000000000000000000000000000021e19e0c9bab2400000000000000000000000000000000000000000000000000000000000024dc9bbaa000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000009a834b70c07c81a9fcd6f22e842bf002fbffbe4dcfee7c08"
    //         );
    //         // swap 10000 USDT for USDC
    //         oneInchData[1] = abi.encode(
    //             address(_USDT),
    //             0,
    //             hex"e449022e00000000000000000000000000000000000000000000000000000002540be400000000000000000000000000000000000000000000000000000000024e089f88000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000018000000000000000000000003416cf6c708da44db2624d63ea0aaef7113527c6cfee7c08"
    //         );

    //         (, , , , , uint256 sanRate, , , ) = _STABLE_MASTER.collateralMap(address(_POOL_MANAGER));
    //         minAmountOut =
    //             ((((amount + amountUSDT + amountFRAX / _DECIMAL_NORM_USDC) * 9900) / _BPS) * 10 ** 18) /
    //             sanRate;

    //         bytes memory addData;
    //         bytes memory swapData = abi.encode(oneInchData, addData);
    //         bytes memory leverageData = abi.encode(true, _alice, swapData);
    //         data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);
    //     }

    //     // we first need to send the tokens before hand, you should always use the swapper
    //     // in another tx to not losse your funds by front running
    //     _USDC.transfer(address(swapper), amount);
    //     _FRAX.transfer(address(swapper), amountFRAX);
    //     _USDT.safeTransfer(address(swapper), amountUSDT);
    //     swapper.swap(IERC20(address(_USDC)), IERC20(address(staker)), _alice, 0, amount, data);

    //     // change the sanRate and mint USDC on the poolManager in case sanRate increase
    //     newSanRate = bound(newSanRate, 0, 1_000_000 ether);
    //     deal(address(_USDC), address(_POOL_MANAGER), type(uint256).max);
    //     stdstore
    //         .target(address(_STABLE_MASTER))
    //         .sig("collateralMap(address)")
    //         .with_key(address(_POOL_MANAGER))
    //         .depth(5)
    //         .checked_write(newSanRate);

    //     // deleverage
    //     uint256 swapMinAmountOut;
    //     amount = staker.balanceOf(_alice);
    //     uint256 netAmount = (amount * newSanRate) / 10 ** 18;
    //     if (netAmount > 19000 * 10 ** 6) {
    //         minAmountOut = (((netAmount - 19000 * 10 ** 6) * 9900) / _BPS);
    //         swapMinAmountOut = (19000 ether * 9900) / _BPS;
    //     } else minAmountOut = netAmount;

    //     {
    //         bytes[] memory oneInchData;
    //         // If there isn't enough to do the swap don't do it
    //         if (netAmount > 19000 * 10 ** 6) {
    //             oneInchData = new bytes[](1);
    //             // swap 19000 USDC for FRAX
    //             oneInchData[0] = abi.encode(
    //                 address(_USDC),
    //                 swapMinAmountOut,
    //                 hex"e449022e000000000000000000000000000000000000000000000000000000046c7cfe000000000000000000000000000000000000000000000003fbfd1ac7f9631196a0000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000018000000000000000000000009a834b70c07c81a9fcd6f22e842bf002fbffbe4dcfee7c08"
    //             );
    //         } else {
    //             oneInchData = new bytes[](0);
    //         }
    //         IERC20[] memory sweepTokens = new IERC20[](1);
    //         sweepTokens[0] = _USDC;
    //         bytes memory removeData = abi.encode(netAmount);
    //         bytes memory swapData = abi.encode(amount, amount, sweepTokens, oneInchData, removeData);
    //         bytes memory leverageData = abi.encode(false, _alice, swapData);
    //         data = abi.encode(address(0), swapMinAmountOut, SwapType.Leverage, leverageData);
    //     }
    //     staker.transfer(address(swapper), amount);
    //     swapper.swap(IERC20(address(staker)), IERC20(address(_FRAX)), _alice, 0, amount, data);

    //     vm.stopPrank();

    //     // The san rate became such that we lost it all
    //     if (netAmount == 0) {
    //         assertEq(_USDC.balanceOf(_alice), 0);
    //         assertEq(_FRAX.balanceOf(_alice), 0);
    //     } else {
    //         assertGe(_USDC.balanceOf(_alice), minAmountOut);
    //         if (netAmount > 19000 * 10 ** 6) assertGe(_FRAX.balanceOf(_alice), swapMinAmountOut);
    //         else assertEq(_FRAX.balanceOf(_alice), 0);
    //     }
    //     assertEq(staker.balanceOf(address(swapper)), 0);
    //     assertEq(staker.balanceOf(_alice), 0);
    //     assertEq(asset.balanceOf(address(_alice)), 0);
    //     assertEq(asset.balanceOf(address(swapper)), 0);
    //     assertEq(asset.balanceOf(address(staker)), 0);
    //     assertEq(_USDT.balanceOf(_alice), 0);
    //     assertEq(_USDC.balanceOf(address(swapper)), 0);
    //     assertEq(_FRAX.balanceOf(address(swapper)), 0);
    //     assertEq(_USDT.balanceOf(address(swapper)), 0);
    //     assertEq(_USDC.balanceOf(address(staker)), 0);
    //     assertEq(_FRAX.balanceOf(address(staker)), 0);
    //     assertEq(_USDT.balanceOf(address(staker)), 0);
    // }
}
