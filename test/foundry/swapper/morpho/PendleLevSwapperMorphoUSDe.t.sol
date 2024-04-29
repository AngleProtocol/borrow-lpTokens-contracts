// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../BaseTest.test.sol";
import "borrow-staked/interfaces/IBorrowStaker.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow-staked/mock/MockTokenPermit.sol";
import { SwapType, BaseLevSwapper, PendleLevSwapperMorphoUSDe, PendleLevSwapperMorpho, Swapper, IUniswapV3Router, IAngleRouterSidechain } from "borrow-staked/swapper/LevSwapper/morpho/implementations/PendleLevSwapperMorphoUSDe.sol";
import { IMorphoBase } from "morpho-blue/interfaces/IMorpho.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract PendleLevSwapperMorphoUSDeTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    address internal constant _ONE_INCH = 0x111111125421cA6dc452d289314280a0f8842A65;
    IUniswapV3Router internal constant _UNI_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAngleRouterSidechain internal constant _ANGLE_ROUTER =
        IAngleRouterSidechain(address(uint160(uint256(keccak256(abi.encodePacked("_fakeAngleRouter"))))));

    uint256 internal constant _BPS = 10000;
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IMorphoBase constant MORPHO = IMorphoBase(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    PendleLevSwapperMorpho public swapper;
    IERC20 public asset;
    IERC20 public collateral;

    function setUp() public override {
        super.setUp();

        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 19759434);
        vm.selectFork(_ethereum);

        // reset coreBorrow because the `makePersistent()` doens't work on my end
        coreBorrow = new MockCoreBorrow();
        coreBorrow.toggleGuardian(_GUARDIAN);
        coreBorrow.toggleGovernor(_GOVERNOR);

        swapper = new PendleLevSwapperMorphoUSDe(coreBorrow, _UNI_V3_ROUTER, _ONE_INCH, _ANGLE_ROUTER, MORPHO);
        asset = swapper.PT();
        collateral = swapper.collateral();

        vm.startPrank(_alice);
        asset.approve(address(swapper), type(uint256).max);
        collateral.approve(address(swapper), type(uint256).max);
        vm.stopPrank();
    }

    function test_Leverage_NoSwap_Success(uint256 amount) public {
        amount = bound(amount, 1 ether, 5 * 10 ** 6 * 1 ether);
        deal(address(collateral), address(_alice), amount);

        vm.startPrank(_alice);

        // intermediary variables
        bytes[] memory oneInchData = new bytes[](0);

        uint256 minAmountOut = amount / 2;
        bytes memory addData;
        bytes memory swapData = abi.encode(oneInchData, addData);
        bytes memory leverageData = abi.encode(true, _alice, swapData);
        bytes memory data = abi.encode(address(0), minAmountOut, SwapType.Leverage, leverageData);

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
        amount = bound(amount, 1 ether, 5 * 10 ** 6 * 1 ether);
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
        uint256 amount = 10000 * (10 ** IERC20Metadata(address(USDC)).decimals());
        deal(address(USDC), address(_alice), amount);

        vm.startPrank(_alice);

        // intermediary variables
        bytes[] memory oneInchData = new bytes[](1);
        // swap USDC for USDe
        oneInchData[0] = abi.encode(
            address(USDC),
            0,
            hex"8770ba91000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000002540be40000000000000000000000000000000000000000000000021972153364ed6c8ea52880000000000000000000003416cf6c708da44db2624d63ea0aaef7113527c6200000000000000000000000435664008f38b0650fbc1c9fc971d0a3bc2f1e47f737be46"
        );

        uint256 minAmountOut = amount / 2;
        bytes memory addData;
        bytes memory swapData = abi.encode(oneInchData, addData);
        bytes memory leverageData = abi.encode(true, _alice, swapData);
        bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

        // we first need to send the tokens before hand, you should always use the swapper
        // in another tx to not loose your funds by front running
        USDC.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(USDC)), IERC20(address(asset)), _alice, 0, amount, data);

        vm.stopPrank();

        assertEq(USDC.balanceOf(_alice), 0);
        assertEq(USDC.balanceOf(address(swapper)), 0);
        assertEq(collateral.balanceOf(_alice), 0);
        assertEq(collateral.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(address(swapper)), 0);
        assertGe(asset.balanceOf(_alice), minAmountOut);
    }

    function test_Deleverage_Swap_Success() public {
        uint256 eps = 1000 ether;
        uint256 amount = 10000 ether;
        deal(address(asset), address(_alice), amount + eps);

        vm.startPrank(_alice);

        // intermediary variables
        bytes[] memory oneInchData = new bytes[](1);
        // swap USDe for USDC
        oneInchData[0] = abi.encode(
            address(collateral),
            0,
            hex"83800a8e0000000000000000000000004c9edd5852cd905f086c759e8383e09bff1e68b300000000000000000000000000000000000000000000021e19e0c9bab2400000000000000000000000000000000000000000000000000000000000024d2639d048100100010800080200000002950460e2b9529d0e00284a5fa2d7bdf3fa4d72f737be46"
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
        swapper.swap(IERC20(address(asset)), IERC20(address(USDC)), _alice, 0, amount, data);

        vm.stopPrank();

        assertGe(USDC.balanceOf(_alice), (amount * 99) / 100 / 10 ** (18 - IERC20Metadata(address(USDC)).decimals()));
        assertEq(USDC.balanceOf(address(swapper)), 0);
        assertGt(collateral.balanceOf(_alice), 0);
        assertEq(collateral.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(_alice), 0);
    }
}
