// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../BaseTest.test.sol";
import "borrow-staked/interfaces/IBorrowStaker.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow-staked/mock/MockTokenPermit.sol";
import { SwapType, BaseLevSwapper, PendleLevSwapperRenzo, PendleLevSwapper, Swapper, IUniswapV3Router, IAngleRouterSidechain } from "borrow-staked/swapper/LevSwapper/pendle/implementations/PendleLevSwapperRenzo.sol";

interface IStETH {
    function submit(address) external payable returns (uint256);
}

contract PendleLevSwapperTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    address internal constant _ONE_INCH = 0x111111125421cA6dc452d289314280a0f8842A65;
    IUniswapV3Router internal constant _UNI_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAngleRouterSidechain internal constant _ANGLE_ROUTER =
        IAngleRouterSidechain(address(uint160(uint256(keccak256(abi.encodePacked("_fakeAngleRouter"))))));

    uint256 internal constant _BPS = 10000;
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    PendleLevSwapper public swapper;
    IERC20 public asset;
    IERC20 public collateral;

    uint256 public constant DEPOSIT_LENGTH = 10;
    uint256 public constant WITHDRAW_LENGTH = 10;

    function setUp() public override {
        super.setUp();

        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 19419563);
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

    function test_Leverage_NoSwap_Success(uint256 amount) public {
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

    function test_Deleverage_NoSwap_Success(uint256 amount) public {
        amount = bound(amount, 10 ** 15, 10 ** 20);
        deal(address(asset), address(_alice), amount);

        vm.startPrank(_alice);

        // intermediary variables
        bytes[] memory oneInchData = new bytes[](0);

        uint256 minAmountOut = amount / 2;
        IERC20[] memory sweepTokens = new IERC20[](0);
        bytes memory removeData = abi.encode(uint256(minAmountOut));
        bytes memory swapData = abi.encode(0, amount, sweepTokens, oneInchData, removeData);
        bytes memory leverageData = abi.encode(false, _alice, swapData);
        bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

        // we first need to send the tokens before hand, you should always use the swapper
        // in another tx to not loose your funds by front running
        asset.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(asset)), IERC20(address(collateral)), _alice, 0, amount, data);

        vm.stopPrank();

        assertGe(collateral.balanceOf(_alice), minAmountOut);
        assertEq(collateral.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(_alice), 0);
    }

    function test_Leverage_Swap_Success() public {
        uint256 amount = 10 ether;
        deal(address(WETH), address(_alice), amount);

        vm.startPrank(_alice);

        // intermediary variables
        bytes[] memory oneInchData = new bytes[](1);
        // swap WETH for ezETH
        oneInchData[0] = abi.encode(
            address(WETH),
            0,
            hex"83800a8e000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000885da5f56f2f70f7280000000000000000000000be80225f09645f172b079394312220637c440a63a20a9a94"
        );

        uint256 minAmountOut = amount / 2;
        bytes memory addData;
        bytes memory swapData = abi.encode(oneInchData, addData);
        bytes memory leverageData = abi.encode(true, _alice, swapData);
        bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

        // we first need to send the tokens before hand, you should always use the swapper
        // in another tx to not loose your funds by front running
        WETH.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(WETH)), IERC20(address(asset)), _alice, 0, amount, data);

        vm.stopPrank();

        assertEq(WETH.balanceOf(_alice), 0);
        assertEq(WETH.balanceOf(address(swapper)), 0);
        assertEq(collateral.balanceOf(_alice), 0);
        assertEq(collateral.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(address(swapper)), 0);
        assertGe(asset.balanceOf(_alice), minAmountOut);
    }

    function test_Deleverage_Swap_Success() public {
        uint256 eps = 1 ether;
        uint256 amount = 10 ether;
        deal(address(asset), address(_alice), amount + eps);

        vm.startPrank(_alice);

        // intermediary variables
        bytes[] memory oneInchData = new bytes[](1);
        // swap WETH for ezETH
        oneInchData[0] = abi.encode(
            address(collateral),
            0,
            hex"83800a8e000000000000000000000000bf5495efe5db9ce00f80364c8b423567e58d21100000000000000000000000000000000000000000000000008ac7230489e8000000000000000000000000000000000000000000000000000089fb4701ff3c3327288000000000000000000000be80225f09645f172b079394312220637c440a63a20a9a94"
        );

        uint256 minAmountOut = amount / 2;
        IERC20[] memory sweepTokens = new IERC20[](1);
        sweepTokens[0] = collateral;
        bytes memory removeData = abi.encode(uint256(minAmountOut));
        bytes memory swapData = abi.encode(0, amount + eps, sweepTokens, oneInchData, removeData);
        bytes memory leverageData = abi.encode(false, _alice, swapData);
        bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

        // we first need to send the tokens before hand, you should always use the swapper
        // in another tx to not loose your funds by front running
        asset.transfer(address(swapper), amount + eps);
        swapper.swap(IERC20(address(asset)), IERC20(address(WETH)), _alice, 0, amount, data);

        vm.stopPrank();

        assertGe(WETH.balanceOf(_alice), (amount * 99) / 100);
        assertEq(WETH.balanceOf(address(swapper)), 0);
        assertGt(collateral.balanceOf(_alice), 0);
        assertEq(collateral.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(_alice), 0);
    }
}
