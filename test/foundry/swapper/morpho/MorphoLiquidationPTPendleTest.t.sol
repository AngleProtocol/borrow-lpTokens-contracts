// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../BaseTest.test.sol";
import "borrow-staked/interfaces/IBorrowStaker.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow-staked/mock/MockTokenPermit.sol";
import { SwapType, BaseLevSwapper, PendleLevSwapperMorphoWeETH, PendleLevSwapperMorpho, Swapper, IUniswapV3Router, IAngleRouterSidechain } from "borrow-staked/swapper/LevSwapper/morpho/implementations/PendleLevSwapperMorphoWeETH.sol";
import { IMorpho, MarketParams, Id, Market } from "morpho-blue/interfaces/IMorpho.sol";
import { MockMorphoOracle } from "../../mock/MockMorphoOracle.sol";
import { MarketParamsLib } from "morpho-blue/libraries/MarketParamsLib.sol";
import { ErrorsLib } from "morpho-blue/libraries/ErrorsLib.sol";

contract MorphoLiquidationPTPendleTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;
    using MarketParamsLib for MarketParams;

    address internal constant _ONE_INCH = 0x111111125421cA6dc452d289314280a0f8842A65;
    IUniswapV3Router internal constant _UNI_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAngleRouterSidechain internal constant _ANGLE_ROUTER =
        IAngleRouterSidechain(address(uint160(uint256(keccak256(abi.encodePacked("_fakeAngleRouter"))))));

    uint256 internal constant _BPS = 10000;
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IMorpho constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    PendleLevSwapperMorpho public swapper;
    IERC20 public asset;
    IERC20 public collateral;
    MockMorphoOracle public oracle;
    MarketParams public marketParams;

    uint256 public constant DEPOSIT_LENGTH = 10;
    uint256 public constant WITHDRAW_LENGTH = 10;

    function setUp() public override {
        super.setUp();

        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 19574108);
        vm.selectFork(_ethereum);

        // reset coreBorrow because the `makePersistent()` doens't work on my end
        coreBorrow = new MockCoreBorrow();
        coreBorrow.toggleGuardian(_GUARDIAN);
        coreBorrow.toggleGovernor(_GOVERNOR);

        swapper = new PendleLevSwapperMorphoWeETH(coreBorrow, _UNI_V3_ROUTER, _ONE_INCH, _ANGLE_ROUTER, MORPHO);
        asset = swapper.PT();
        collateral = swapper.collateral();

        // create the oracle between collateral and loan token
        oracle = new MockMorphoOracle(10 ** 36);

        // create the morpho market with WETH (for testing purposes and liquidity)
        marketParams = MarketParams({
            loanToken: address(WETH),
            collateralToken: address(asset),
            oracle: address(oracle),
            irm: 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC,
            lltv: 0.77 ether
        });
        MORPHO.createMarket(marketParams);

        vm.startPrank(_alice);
        asset.approve(address(swapper), type(uint256).max);
        collateral.approve(address(swapper), type(uint256).max);
        vm.stopPrank();

        // seed the market with liquidity
        uint256 supplyAmount = 100 ether;
        deal(address(WETH), address(_dylan), supplyAmount);
        vm.startPrank(_dylan);
        WETH.safeApprove(address(MORPHO), type(uint256).max);
        MORPHO.supply(marketParams, supplyAmount, 0, _dylan, hex"");
        vm.stopPrank();
    }

    function test_RevertWhen_Liquidate_Healthy(uint256 amount) public {
        // create a position
        amount = bound(amount, 0.001 ether, 100 ether);
        uint256 borrowAmount = amount / 2;
        deal(address(asset), address(_alice), amount);

        vm.startPrank(_alice);
        asset.safeApprove(address(MORPHO), amount);
        MORPHO.supplyCollateral(marketParams, amount, _alice, hex"");
        MORPHO.borrow(marketParams, borrowAmount, 0, _alice, _alice);
        vm.stopPrank();

        // revert when liquidate healthy position
        vm.startPrank(_bob);
        bytes memory liquidateData;
        {
            // intermediary variables
            bytes[] memory oneInchData = new bytes[](1);
            // swap weETH for WETH
            oneInchData[0] = abi.encode(
                address(collateral),
                0,
                hex"83800a8e000000000000000000000000cd5fe23c85820f7b72d0926fc9b05b43e359b7ee0000000000000000000000000000000000000000000000008ac7230489e800000000000000000000000000000000000000000000000000008df12dbf0ec541092800000000000000000000007a415b19932c0105c82fdb6b720bb01b0cc2cae3a20a9a94"
            );

            uint256 minAmountOut = amount / 2;
            IERC20[] memory sweepTokens = new IERC20[](1);
            sweepTokens[0] = collateral;
            bytes memory removeData = abi.encode(uint256(minAmountOut));
            bytes memory swapData = abi.encode(0, amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);
            liquidateData = abi.encode(address(asset), address(WETH), amount, data);
        }
        vm.expectRevert(bytes(ErrorsLib.HEALTHY_POSITION));
        swapper.liquidate(marketParams, _alice, amount, liquidateData);
        vm.stopPrank();
    }

    function test_Liquidate_Success() public {
        // create a position
        uint256 amount = 12 ether;
        uint256 eps = 2 ether;
        uint256 borrowAmount = amount / 2;
        deal(address(asset), address(_alice), amount);

        vm.startPrank(_alice);
        asset.safeApprove(address(MORPHO), amount);
        MORPHO.supplyCollateral(marketParams, amount, _alice, hex"");
        MORPHO.borrow(marketParams, borrowAmount, 0, _alice, _alice);
        vm.stopPrank();

        // change the oracle value to make it liquidatable
        oracle.update(10 ** 36 / 2);

        // revert when liquidate healthy position
        vm.startPrank(_bob);
        bytes memory liquidateData;
        {
            // intermediary variables
            bytes[] memory oneInchData = new bytes[](1);
            // swap weETH for WETH
            // missing something to make it work for any amount
            oneInchData[0] = abi.encode(
                address(collateral),
                0,
                abi.encodePacked(
                    hex"83800a8e000000000000000000000000cd5fe23c85820f7b72d0926fc9b05b43e359b7ee000000000000000000000000000000000000000000000000",
                    bytes32ToBytes(bytes32(amount - eps)),
                    hex"0000000000000000000000000000000000000000000000008df12dbf0ec541092800000000000000000000007a415b19932c0105c82fdb6b720bb01b0cc2cae3a20a9a94"
                )
            );

            uint256 minAmountOut = amount / 2;
            IERC20[] memory sweepTokens = new IERC20[](1);
            sweepTokens[0] = collateral;
            bytes memory removeData = abi.encode(uint256(minAmountOut));
            bytes memory swapData = abi.encode(0, amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _bob, swapData);
            bytes memory data = abi.encode(_bob, 0, SwapType.Leverage, leverageData);
            liquidateData = abi.encode(address(asset), address(WETH), amount, data);
        }
        swapper.liquidate(marketParams, _alice, amount, liquidateData);
        vm.stopPrank();
    }

    function bytes32ToBytes(bytes32 data) internal view returns (bytes memory result) {
        uint256 i = 0;
        while (i < 32 && uint256(bytes32(data[i])) == 0) {
            ++i;
        }
        result = new bytes(32 - i);
        uint256 count = 0;
        while (count < result.length) {
            result[count] = data[i + count];
            ++count;
        }
        return result;
    }
}
