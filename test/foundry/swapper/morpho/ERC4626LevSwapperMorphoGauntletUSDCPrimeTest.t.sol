// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../BaseTest.test.sol";
import "borrow-staked/interfaces/IBorrowStaker.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow-staked/mock/MockTokenPermit.sol";
import { SwapType, BaseLevSwapper, ERC4626LevSwapperMorphoGauntletUSDCPrime, Swapper, IUniswapV3Router, IAngleRouterSidechain } from "borrow-staked/swapper/LevSwapper/morpho/implementations/ERC4626LevSwapperMorphoGauntletUSDCPrime.sol";
import { IMorphoBase } from "morpho-blue/interfaces/IMorpho.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ERC4626LevSwapperMorphoGauntletUSDCPrimeTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    address internal constant _ONE_INCH = 0x111111125421cA6dc452d289314280a0f8842A65;
    IUniswapV3Router internal constant _UNI_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAngleRouterSidechain internal constant _ANGLE_ROUTER =
        IAngleRouterSidechain(address(uint160(uint256(keccak256(abi.encodePacked("_fakeAngleRouter"))))));

    uint256 internal constant _BPS = 10000;
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IMorphoBase constant MORPHO = IMorphoBase(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    ERC4626LevSwapperMorphoGauntletUSDCPrime public swapper;
    IERC20 public asset;
    IERC20 public collateral;

    function setUp() public override {
        super.setUp();

        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 19668260);
        vm.selectFork(_ethereum);

        // reset coreBorrow because the `makePersistent()` doens't work on my end
        coreBorrow = new MockCoreBorrow();
        coreBorrow.toggleGuardian(_GUARDIAN);
        coreBorrow.toggleGovernor(_GOVERNOR);

        swapper = new ERC4626LevSwapperMorphoGauntletUSDCPrime(
            coreBorrow,
            _UNI_V3_ROUTER,
            _ONE_INCH,
            _ANGLE_ROUTER,
            MORPHO
        );
        asset = swapper.token();
        collateral = swapper.asset();

        vm.startPrank(_alice);
        asset.approve(address(swapper), type(uint256).max);
        collateral.approve(address(swapper), type(uint256).max);
        vm.stopPrank();
    }

    function test_Leverage_NoSwap_Success(uint256 amount) public {
        amount = bound(amount, 10 ** 5, 10 ** 10);
        deal(address(collateral), address(_alice), amount);

        vm.startPrank(_alice);

        // intermediary variables
        bytes[] memory oneInchData = new bytes[](0);

        uint256 minAmountOut = IERC4626(address(asset)).previewDeposit(amount);
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

        uint256 minAmountOut = IERC4626(address(asset)).previewRedeem(amount);
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
        // swap wETH for USDC
        oneInchData[0] = abi.encode(
            address(WETH),
            0,
            hex"83800a8e000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000008ac7230489e80000000000000000000000000000000000000000000000000000000000071c36365228000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640f737be46"
        );

        // oracle USDC --> ETH
        (, int256 oracleUSDCETH, , , ) = AggregatorV3Interface(0x986b5E1e1755e3C2440e960477f25201B0a8bbD4)
            .latestRoundData();
        // set to the right base and take a margin on the amount received
        uint256 minAmountOut = (amount *
            10 ** AggregatorV3Interface(0x986b5E1e1755e3C2440e960477f25201B0a8bbD4).decimals() *
            (0.999 ether)) / (uint256(oracleUSDCETH) * 1 ether * 10 ** 12);
        minAmountOut = IERC4626(address(asset)).previewDeposit(minAmountOut);
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
        uint256 amount = 10000 ether;
        deal(address(asset), address(_alice), amount);

        vm.startPrank(_alice);

        // intermediary variables
        bytes[] memory oneInchData = new bytes[](1);
        // swap USDC for WETH
        oneInchData[0] = abi.encode(
            address(collateral),
            0,
            hex"83800a8e000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000002540be4000000000000000000000000000000000000000000000000002ca57fc5fa41d7b828800000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640f737be46"
        );

        // oracle USDC --> ETH
        (, int256 oracleUSDCETH, , , ) = AggregatorV3Interface(0x986b5E1e1755e3C2440e960477f25201B0a8bbD4)
            .latestRoundData();
        // set to the right base + margin
        uint256 minAmountOut = (IERC4626(address(asset)).previewRedeem(amount) * uint256(oracleUSDCETH) * 0.999 ether) /
            (10 ** AggregatorV3Interface(0x986b5E1e1755e3C2440e960477f25201B0a8bbD4).decimals() * 10 ** 12 * 1 ether);
        IERC20[] memory sweepTokens = new IERC20[](1);
        sweepTokens[0] = collateral;
        bytes memory removeData = abi.encode(uint256(minAmountOut));
        bytes memory swapData = abi.encode(0, amount, sweepTokens, oneInchData, removeData);
        bytes memory leverageData = abi.encode(false, _alice, swapData);
        bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

        // we first need to send the tokens before hand, you should always use the swapper
        // in another tx to not loose your funds by front running
        asset.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(asset)), IERC20(address(WETH)), _alice, 0, amount, data);

        vm.stopPrank();

        assertGe(WETH.balanceOf(_alice), minAmountOut);
        assertEq(WETH.balanceOf(address(swapper)), 0);
        assertGt(collateral.balanceOf(_alice), 0);
        assertEq(collateral.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(_alice), 0);
    }
}
