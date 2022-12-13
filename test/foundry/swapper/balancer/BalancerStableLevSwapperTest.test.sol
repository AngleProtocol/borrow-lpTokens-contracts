// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../BaseTest.test.sol";
import "../../../../contracts/interfaces/IBorrowStaker.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "../../../../contracts/interfaces/external/curve/IMetaPool2.sol";
import "borrow/interfaces/coreModule/IStableMaster.sol";
import "borrow/interfaces/coreModule/IPoolManager.sol";
import "../../../../contracts/mock/MockTokenPermit.sol";
import { SwapType, BaseLevSwapper, MockBalancerStableLevSwapper, Swapper, IUniswapV3Router, IAngleRouterSidechain, IBalancerVault, IAsset } from "../../../../contracts/mock/MockBalancerStableLevSwapper.sol";
import { MockBorrowStaker } from "../../../../contracts/mock/MockBorrowStaker.sol";

contract BalancerStableLevSwapperTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    address internal constant _ONE_INCH = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
    IUniswapV3Router internal constant _UNI_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAngleRouterSidechain internal constant _ANGLE_ROUTER =
        IAngleRouterSidechain(address(uint160(uint256(keccak256(abi.encodePacked("_fakeAngleRouter"))))));
    IERC20 public asset = IERC20(0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
    IERC20 internal constant _WSTETH = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 internal constant _WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    IERC20 internal constant _LP_TOKEN = IERC20(0x32296969Ef14EB0c6d29669C550D4a0449130230);
    IBalancerVault internal constant _BALANCER_VAULT = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    uint256 internal constant _BPS = 10000;
    MockBalancerStableLevSwapper public swapper;
    MockBorrowStaker public stakerImplementation;
    MockBorrowStaker public staker;
    uint8 public decimalToken = 18;
    uint256 public maxTokenAmount = 10**15 * 10**decimalToken;
    uint256 public constant SLIPPAGE_BPS = 9900;

    uint256 public constant DEPOSIT_LENGTH = 10;
    uint256 public constant WITHDRAW_LENGTH = 10;
    uint256 public constant CLAIMABLE_LENGTH = 50;
    uint256 public constant CLAIM_LENGTH = 50;

    function setUp() public override {
        super.setUp();

        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 15824909);
        vm.selectFork(_ethereum);

        coreBorrow = new MockCoreBorrow();
        coreBorrow.toggleGuardian(_GUARDIAN);
        coreBorrow.toggleGovernor(_GOVERNOR);

        stakerImplementation = new MockBorrowStaker();
        staker = MockBorrowStaker(
            deployUpgradeable(address(stakerImplementation), abi.encodeWithSelector(staker.setAsset.selector, asset))
        );
        staker.initialize(coreBorrow);
        staker.setAsset(_LP_TOKEN);

        swapper = new MockBalancerStableLevSwapper(
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
        tokens[0] = _LP_TOKEN;
        spenders[0] = address(staker);
        amounts[0] = type(uint256).max;
        swapper.changeAllowance(tokens, spenders, amounts);
        vm.stopPrank();

        vm.startPrank(_alice);
        _WETH.approve(address(swapper), type(uint256).max);
        _WSTETH.approve(address(swapper), type(uint256).max);
        vm.stopPrank();
    }

    function _joinOneCoin(uint256 amount, IERC20 token) internal {
        vm.startPrank(_alice);
        bytes memory data;
        {
            bytes memory addData;
            bytes[] memory oneInchData;
            bytes memory swapData = abi.encode(oneInchData, addData);
            bytes memory leverageData = abi.encode(true, _alice, swapData);
            data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);
        }
        // we first need to send the tokens before hand
        token.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(token)), IERC20(address(staker)), _alice, 0, amount, data);
        vm.stopPrank();
    }

    function testInitialization() public {
        assertEq(_WSTETH.allowance(address(swapper), address(_BALANCER_VAULT)), type(uint256).max);
        assertEq(_WETH.allowance(address(swapper), address(_BALANCER_VAULT)), type(uint256).max);
        assertEq(_LP_TOKEN.allowance(address(swapper), address(staker)), type(uint256).max);
        assertEq(address(swapper.lpToken()), 0x32296969Ef14EB0c6d29669C550D4a0449130230);
        assertEq(address(swapper.tokens()[0]), 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
        assertEq(address(swapper.tokens()[1]), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        assertEq(swapper.poolId(), bytes32(0x32296969ef14eb0c6d29669c550d4a0449130230000200000000000000000080));
    }

    function testOneTokenWETHJoin(uint256 amount) public {
        amount = bound(amount, 10**6, 10**24);
        deal(address(_WETH), address(_alice), amount);
        _joinOneCoin(amount, _WETH);
        uint256 balance = staker.balanceOf(_alice);
        assertEq(balance, _LP_TOKEN.balanceOf(address(staker)));
        assertGt(balance, 0);
    }

    function testRevertOneTokenWETHJoin(uint256 amount) public {
        amount = bound(amount, 10**6, 10**24);

        deal(address(_WETH), address(_alice), amount);
        vm.startPrank(_alice);

        bytes memory data;
        {
            bytes memory addData;
            bytes[] memory oneInchData;
            bytes memory swapData = abi.encode(oneInchData, addData);
            bytes memory leverageData = abi.encode(true, _alice, swapData);
            data = abi.encode(address(0), amount, SwapType.Leverage, leverageData);
        }
        // we first need to send the tokens before hand
        _WETH.transfer(address(swapper), amount);
        vm.expectRevert(Swapper.TooSmallAmountOut.selector);
        swapper.swap(IERC20(address(_WETH)), IERC20(address(staker)), _alice, 0, amount, data);
        vm.stopPrank();
    }

    function testOneTokenWSTETHJoin(uint256 amount) public {
        amount = bound(amount, 10**6, 10**24);

        deal(address(_WSTETH), address(_alice), amount);
        _joinOneCoin(amount, _WSTETH);
        uint256 balance = staker.balanceOf(_alice);
        assertEq(balance, _LP_TOKEN.balanceOf(address(staker)));
        assertGt(balance, 0);
    }

    function testRevertOneTokenWSTETHJoin(uint256 amount) public {
        amount = bound(amount, 10**6, 10**24);

        deal(address(_WSTETH), address(_alice), amount);
        vm.startPrank(_alice);

        bytes memory data;
        {
            bytes memory addData;
            bytes[] memory oneInchData;
            bytes memory swapData = abi.encode(oneInchData, addData);
            bytes memory leverageData = abi.encode(true, _alice, swapData);
            // If you bring 1 token, you'll get less LP tokens
            data = abi.encode(address(0), amount, SwapType.Leverage, leverageData);
        }
        // we first need to send the tokens before hand
        _WSTETH.transfer(address(swapper), amount);
        vm.expectRevert(Swapper.TooSmallAmountOut.selector);
        swapper.swap(IERC20(address(_WSTETH)), IERC20(address(staker)), _alice, 0, amount, data);
        vm.stopPrank();
    }

    function testBothTokensJoin(uint256 amount0, uint256 amount1) public {
        amount0 = bound(amount0, 10**6, 10**24);
        amount1 = bound(amount1, 10**6, 10**24);

        deal(address(_WETH), address(_alice), amount0);
        deal(address(_WSTETH), address(_alice), amount1);
        vm.startPrank(_alice);

        bytes memory data;
        {
            bytes memory addData;
            bytes[] memory oneInchData;
            bytes memory swapData = abi.encode(oneInchData, addData);
            bytes memory leverageData = abi.encode(true, _alice, swapData);
            data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);
        }
        // we first need to send the tokens before hand
        _WETH.transfer(address(swapper), amount0);
        _WSTETH.transfer(address(swapper), amount1);
        swapper.swap(IERC20(address(_WSTETH)), IERC20(address(staker)), _alice, 0, amount1, data);
        vm.stopPrank();
        uint256 balance = staker.balanceOf(_alice);
        assertEq(balance, _LP_TOKEN.balanceOf(address(staker)));
        assertGt(balance, 0);
    }

    function testRevertBothTokensJoin(uint256 amount0, uint256 amount1) public {
        amount0 = bound(amount0, 10**6, 10**24);
        amount1 = bound(amount1, 10**6, 10**24);

        deal(address(_WETH), address(_alice), amount0);
        deal(address(_WSTETH), address(_alice), amount1);
        vm.startPrank(_alice);

        bytes memory data;
        {
            bytes memory addData;
            bytes[] memory oneInchData;
            bytes memory swapData = abi.encode(oneInchData, addData);
            bytes memory leverageData = abi.encode(true, _alice, swapData);
            data = abi.encode(address(0), amount0 + amount1, SwapType.Leverage, leverageData);
        }
        // we first need to send the tokens before hand
        _WETH.transfer(address(swapper), amount0);
        _WSTETH.transfer(address(swapper), amount1);
        vm.expectRevert(Swapper.TooSmallAmountOut.selector);
        swapper.swap(IERC20(address(_WSTETH)), IERC20(address(staker)), _alice, 0, amount1, data);
        vm.stopPrank();
        uint256 balance = staker.balanceOf(_alice);
        assertEq(balance, _LP_TOKEN.balanceOf(address(staker)));
    }

    function testOneTokenExitWETH(uint256 amount, uint256 proportion) public {
        amount = bound(amount, 10**9, 10**24);
        deal(address(_WETH), address(_alice), amount);
        _joinOneCoin(amount, _WETH);
        vm.startPrank(_alice);
        uint256 balance = staker.balanceOf(_alice);
        proportion = bound(proportion, 10**6, 10**9);
        uint256 amountToRemove = (balance * proportion) / 10**9;
        bytes memory data;
        {
            bytes memory removeData = abi.encode(
                // MockBalancerStableLevSwapper.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT
                0,
                1
            );
            bytes[] memory oneInchData;
            IERC20[] memory sweepTokens;
            bytes memory swapData = abi.encode(amountToRemove, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amountToRemove);
        swapper.swap(IERC20(address(staker)), IERC20(address(_WETH)), _alice, 0, amount, data);
        vm.stopPrank();
        assertEq(staker.balanceOf(_alice), balance - amountToRemove);
        assertEq(staker.balanceOf(_alice), balance - amountToRemove);
        assertGt(_WETH.balanceOf(_alice), 0);
        assertEq(_LP_TOKEN.balanceOf(_alice), 0);
    }

    function testOneTokenExitWSTETH(uint256 amount, uint256 proportion) public {
        amount = bound(amount, 10**9, 10**23);
        deal(address(_WETH), address(_alice), amount);
        _joinOneCoin(amount, _WETH);
        vm.startPrank(_alice);
        uint256 balance = staker.balanceOf(_alice);
        proportion = bound(proportion, 10**6, 10**9);
        uint256 amountToRemove = (balance * proportion) / 10**9;
        bytes memory data;
        {
            bytes memory removeData = abi.encode(0, 0);
            bytes[] memory oneInchData;
            IERC20[] memory sweepTokens;
            bytes memory swapData = abi.encode(amountToRemove, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amountToRemove);
        swapper.swap(IERC20(address(staker)), IERC20(address(_WSTETH)), _alice, 0, amount, data);
        vm.stopPrank();
        assertEq(staker.balanceOf(_alice), balance - amountToRemove);
        assertEq(staker.balanceOf(_alice), balance - amountToRemove);
        assertGt(_WSTETH.balanceOf(_alice), 0);
        assertEq(_WETH.balanceOf(_alice), 0);
        assertEq(_LP_TOKEN.balanceOf(_alice), 0);
    }

    function testMultiTokenExitNoSweep(uint256 amount, uint256 proportion) public {
        amount = bound(amount, 10**18, 10**24);
        deal(address(_WETH), address(_alice), amount);
        _joinOneCoin(amount, _WETH);
        vm.startPrank(_alice);
        uint256 balance = staker.balanceOf(_alice);
        proportion = bound(proportion, 10**8, 10**9);
        uint256 amountToRemove = (balance * proportion) / 10**9;
        bytes memory data;
        {
            bytes memory removeData = abi.encode(1, 0);
            bytes[] memory oneInchData;
            IERC20[] memory sweepTokens;
            bytes memory swapData = abi.encode(amountToRemove, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amountToRemove);

        swapper.swap(IERC20(address(staker)), IERC20(address(_WSTETH)), _alice, 0, amount, data);
        vm.stopPrank();
        assertEq(staker.balanceOf(_alice), balance - amountToRemove);
        assertEq(staker.balanceOf(_alice), balance - amountToRemove);
        assertGt(_WSTETH.balanceOf(_alice), 0);
        // In this case if we don't sweep balance is 0
        assertEq(_WETH.balanceOf(_alice), 0);
        assertEq(_LP_TOKEN.balanceOf(_alice), 0);
    }

    function testMultiTokenExitWithSweep(uint256 amount, uint256 proportion) public {
        amount = bound(amount, 10**18, 10**24);
        deal(address(_WETH), address(_alice), amount);
        _joinOneCoin(amount, _WETH);
        vm.startPrank(_alice);
        uint256 balance = staker.balanceOf(_alice);
        proportion = bound(proportion, 10**8, 10**9);
        uint256 amountToRemove = (balance * proportion) / 10**9;
        bytes memory data;
        {
            bytes memory removeData = abi.encode(1, 0);
            bytes[] memory oneInchData;
            IERC20[] memory sweepTokens = new IERC20[](1);
            sweepTokens[0] = IERC20(_WETH);
            bytes memory swapData = abi.encode(amountToRemove, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amountToRemove);

        swapper.swap(IERC20(address(staker)), IERC20(address(_WSTETH)), _alice, 0, amount, data);
        vm.stopPrank();
        assertEq(staker.balanceOf(_alice), balance - amountToRemove);
        assertEq(staker.balanceOf(_alice), balance - amountToRemove);
        assertGt(_WSTETH.balanceOf(_alice), 0);
        // In this case, we swept so is non 0
        assertGt(_WETH.balanceOf(_alice), 0);
        assertEq(_LP_TOKEN.balanceOf(_alice), 0);
    }

    function testStakedTokenExit(uint256 amount, uint256 proportion) public {
        amount = bound(amount, 10**18, 10**24);
        deal(address(_WETH), address(_alice), amount);
        _joinOneCoin(amount, _WETH);
        vm.startPrank(_alice);
        uint256 balance = staker.balanceOf(_alice);
        proportion = bound(proportion, 10**8, 10**9);
        uint256 amountToRemove = (balance * proportion) / 10**9;
        bytes memory data;
        {
            bytes memory removeData = abi.encode(2, 0);
            bytes[] memory oneInchData;
            IERC20[] memory sweepTokens;
            bytes memory swapData = abi.encode(amountToRemove, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amountToRemove);

        swapper.swap(IERC20(address(staker)), IERC20(address(_LP_TOKEN)), _alice, 0, amount, data);
        vm.stopPrank();
        assertEq(staker.balanceOf(_alice), balance - amountToRemove);
        assertEq(staker.balanceOf(_alice), balance - amountToRemove);
        assertEq(_WSTETH.balanceOf(_alice), 0);
        assertEq(_WETH.balanceOf(_alice), 0);
        assertEq(_LP_TOKEN.balanceOf(_alice), amountToRemove);
    }
}
