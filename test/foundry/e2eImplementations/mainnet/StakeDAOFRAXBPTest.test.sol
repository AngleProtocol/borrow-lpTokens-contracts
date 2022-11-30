// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../../BaseTest.test.sol";
import "../../../../contracts/interfaces/IBorrowStaker.sol";
import "../../../../contracts/interfaces/ICoreBorrow.sol";
import "../../../../contracts/interfaces/external/stakeDAO/IStakeCurveVault.sol";
import "../../../../contracts/interfaces/external/curve/IMetaPool2.sol";
import "../../../../contracts/interfaces/coreModule/IStableMaster.sol";
import "../../../../contracts/interfaces/coreModule/IPoolManager.sol";
import "../../../../contracts/mock/MockTokenPermit.sol";

import { CurveRemovalType, SwapType, BaseLevSwapper, MockCurveLevSwapperFRAXBP, Swapper, IUniswapV3Router, IAngleRouterSidechain } from "../../../../contracts/mock/implementations/swapper/mainnet/MockCurveLevSwapperFRAXBP.sol";
import { StakeDAOFRAXBPStaker } from "../../../../contracts/staker/curve/implementations/mainnet/StakeDAOFRAXBPStaker.sol";

contract StakeDAOFRAXBPTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    address internal constant _ONE_INCH = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
    IUniswapV3Router internal constant _UNI_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAngleRouterSidechain internal constant _ANGLE_ROUTER =
        IAngleRouterSidechain(address(uint160(uint256(keccak256(abi.encodePacked("_fakeAngleRouter"))))));
    IERC20 public asset = IERC20(0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC);
    IERC20 internal constant _USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 internal constant _USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 internal constant _FRAX = IERC20(0x853d955aCEf822Db058eb8505911ED77F175b99e);
    uint256 internal constant _DECIMAL_NORM_USDC = 10**12;
    uint256 internal constant _DECIMAL_NORM_USDT = 10**12;
    IERC20 internal constant _STAKEDAO_GAUGE = IERC20(0xBe77585F4159e674767Acf91284160E8C09b96D8);
    IStakeCurveVault internal constant _STAKEDAO_VAULT = IStakeCurveVault(0x11D87d278432Bb2CA6ce175e4a8B4AbDaDE80Fd0);

    IMetaPool2 internal constant _METAPOOL = IMetaPool2(0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2);

    uint256 internal constant _BPS = 10000;
    MockCurveLevSwapperFRAXBP public swapper;
    StakeDAOFRAXBPStaker public stakerImplementation;
    StakeDAOFRAXBPStaker public staker;
    uint8 public decimalToken = 18;
    uint256 public maxTokenAmount = 10**15 * 10**decimalToken;
    uint256 public SLIPPAGE_BPS = 9900;

    // no need to do long sequences because we just need to test whether it is the right pools at stake
    uint256 public constant DEPOSIT_LENGTH = 2;
    uint256 public constant WITHDRAW_LENGTH = 2;
    uint256 public constant CLAIMABLE_LENGTH = 5;
    uint256 public constant CLAIM_LENGTH = 5;

    function setUp() public override {
        super.setUp();

        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 15824909);
        vm.selectFork(_ethereum);

        // reset coreBorrow because the `makePersistent()` doens't work on my end
        coreBorrow = new MockCoreBorrow();
        coreBorrow.toggleGuardian(_GUARDIAN);
        coreBorrow.toggleGovernor(_GOVERNOR);

        stakerImplementation = new StakeDAOFRAXBPStaker();
        staker = StakeDAOFRAXBPStaker(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.initialize.selector, coreBorrow)
            )
        );

        swapper = new MockCurveLevSwapperFRAXBP(
            coreBorrow,
            _UNI_V3_ROUTER,
            _ONE_INCH,
            _ANGLE_ROUTER,
            IBorrowStaker(address(staker))
        );

        assertEq(staker.name(), "Angle Curve.fi FRAX/USDC Staker");
        assertEq(staker.symbol(), "agstk-crvFRAX");
        assertEq(staker.decimals(), 18);

        vm.startPrank(_GOVERNOR);
        IERC20[] memory tokens = new IERC20[](1);
        address[] memory spenders = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = asset;
        spenders[0] = address(staker);
        amounts[0] = type(uint256).max;
        swapper.changeAllowance(tokens, spenders, amounts);
        vm.stopPrank();

        vm.startPrank(_alice);
        _USDC.approve(address(swapper), type(uint256).max);
        _USDT.safeIncreaseAllowance(address(swapper), type(uint256).max);
        _FRAX.approve(address(swapper), type(uint256).max);
        vm.stopPrank();

        // clear out the token not deposited yet from the strategy
        deal(address(asset), address(_alice), 1);
        vm.startPrank(_alice);
        asset.approve(address(_STAKEDAO_VAULT), 1);
        _STAKEDAO_VAULT.deposit(_alice, 1, true);
        vm.stopPrank();
    }

    function testLeverageNoUnderlyingTokensDeposited(uint256 amount) public {
        amount = bound(amount, 1, 10**27);

        _depositDirect(amount);

        assertEq(staker.balanceOf(_alice), amount);
        assertEq(_STAKEDAO_GAUGE.balanceOf(address(staker)), amount);
        assertEq(staker.balanceOf(_alice), staker.totalSupply());
        assertEq(_USDC.balanceOf(_alice), 0);
        assertEq(_FRAX.balanceOf(_alice), 0);
        _assertCommonLeverage();
    }

    function testLeverageSuccess(uint256[2] memory amounts) public {
        uint256 minAmountOut = _depositLiquidity(amounts);

        assertGt(staker.balanceOf(_alice), minAmountOut);
        assertGt(_STAKEDAO_GAUGE.balanceOf(address(staker)), minAmountOut);
        assertEq(staker.balanceOf(_alice), staker.totalSupply());
        assertEq(_USDC.balanceOf(_alice), 0);
        assertEq(_FRAX.balanceOf(_alice), 0);
        _assertCommonLeverage();
    }

    function testDeleverageOneCoinToken2(
        uint256[2] memory amounts,
        uint256 swapAmount,
        int128 coinSwapFrom,
        int128 coinSwapTo
    ) public {
        _depositLiquidity(amounts);
        _swapToImbalance(coinSwapFrom, coinSwapTo, swapAmount);

        int128 coinIndex = 0;
        IERC20 outToken = IERC20(address(_FRAX));

        uint256 minOneCoin = _deleverageOneCoin(coinIndex, outToken);

        assertEq(_USDC.balanceOf(_alice), 0);
        assertGe(_FRAX.balanceOf(_alice), minOneCoin);
        _assertCommonDeleverage();
    }

    function testDeleverageBalance(
        uint256[2] memory amounts,
        uint256 swapAmount,
        int128 coinSwapFrom,
        int128 coinSwapTo
    ) public {
        _depositLiquidity(amounts);
        _swapToImbalance(coinSwapFrom, coinSwapTo, swapAmount);
        uint256[2] memory minAmounts = _deleverageBalance();

        assertGe(_FRAX.balanceOf(_alice), minAmounts[0]);
        assertGe(_USDC.balanceOf(_alice), minAmounts[1]);
        _assertCommonDeleverage();
    }

    function testDeleverageImbalance(
        uint256[2] memory amounts,
        uint256 swapAmount,
        int128 coinSwapFrom,
        int128 coinSwapTo,
        uint256 proportionWithdrawToken
    ) public {
        _depositLiquidity(amounts);
        _swapToImbalance(coinSwapFrom, coinSwapTo, swapAmount);

        proportionWithdrawToken = bound(proportionWithdrawToken, 0, 10**9);

        (uint256[2] memory amountOut, uint256 keptLPToken) = _deleverageImbalance(proportionWithdrawToken);

        assertGe(_USDC.balanceOf(_alice), amountOut[1]);
        assertGe(_FRAX.balanceOf(_alice), amountOut[0]);
        assertEq(_USDC.balanceOf(_bob), 0);
        assertEq(_FRAX.balanceOf(_bob), 0);
        assertLe(staker.balanceOf(_bob), keptLPToken);
        assertLe(staker.totalSupply(), keptLPToken);
        assertLe(asset.balanceOf(address(staker)), keptLPToken);
        _assertCommonLeverage();
    }

    // ============================== HELPER FUNCTIONS =============================

    function _depositDirect(uint256 amount) internal {
        deal(address(asset), address(_alice), amount);
        vm.startPrank(_alice);
        // intermediary variables
        bytes[] memory oneInchData = new bytes[](0);

        bytes memory addData;
        bytes memory swapData = abi.encode(oneInchData, addData);
        bytes memory leverageData = abi.encode(true, _alice, swapData);
        bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

        // we first need to send the tokens before hand, you should always use the swapper
        // in another tx to not losse your funds by front running
        asset.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(asset)), IERC20(address(staker)), _alice, 0, amount, data);

        vm.stopPrank();
    }

    function _depositLiquidity(uint256[2] memory amounts) internal returns (uint256 minAmountOut) {
        // FRAX - USDC
        amounts[0] = bound(amounts[0], 1, 10**23);
        amounts[1] = bound(amounts[1], 1, 10**11);

        deal(address(_FRAX), address(_alice), amounts[0]);
        deal(address(_USDC), address(_alice), amounts[1]);

        vm.startPrank(_alice);

        // intermediary variables
        bytes[] memory oneInchData = new bytes[](0);

        minAmountOut =
            (IMetaPool2(address(_METAPOOL)).calc_token_amount([amounts[0], amounts[1]], true) * SLIPPAGE_BPS) /
            _BPS;

        bytes memory addData;
        bytes memory swapData = abi.encode(oneInchData, addData);
        bytes memory leverageData = abi.encode(true, _alice, swapData);
        bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

        // we first need to send the tokens before hand, you should always use the swapper
        // in another tx to not loose your funds via front running
        _USDC.transfer(address(swapper), amounts[1]);
        _FRAX.transfer(address(swapper), amounts[0]);
        swapper.swap(IERC20(address(_USDC)), IERC20(address(staker)), _alice, 0, amounts[0], data);

        vm.stopPrank();
    }

    function _deleverageOneCoin(int128 coinIndex, IERC20 outToken) internal returns (uint256) {
        vm.startPrank(_alice);
        // deleverage
        uint256 amount = staker.balanceOf(_alice);
        uint256 minOneCoin;
        bytes memory data;
        {
            bytes[] memory oneInchData = new bytes[](0);
            IERC20[] memory sweepTokens = new IERC20[](0);
            // sweepTokens[0] = _USDC;
            minOneCoin = (_METAPOOL.calc_withdraw_one_coin(amount, coinIndex) * SLIPPAGE_BPS) / _BPS;
            bytes memory removeData = abi.encode(CurveRemovalType.oneCoin, abi.encode(coinIndex, minOneCoin));
            bytes memory swapData = abi.encode(amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), minOneCoin, SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(staker)), outToken, _alice, 0, amount, data);

        vm.stopPrank();

        return minOneCoin;
    }

    function _deleverageBalance() internal returns (uint256[2] memory minAmounts) {
        vm.startPrank(_alice);
        // deleverage
        uint256 amount = staker.balanceOf(_alice);
        bytes memory data;
        {
            bytes[] memory oneInchData = new bytes[](0);
            IERC20[] memory sweepTokens = new IERC20[](1);
            sweepTokens[0] = _USDC;
            minAmounts = [
                (_METAPOOL.balances(0) * amount * SLIPPAGE_BPS) / (_BPS * asset.totalSupply()),
                (_METAPOOL.balances(1) * amount * SLIPPAGE_BPS) / (_BPS * asset.totalSupply())
            ];
            bytes memory removeData = abi.encode(CurveRemovalType.balance, abi.encode(minAmounts));
            bytes memory swapData = abi.encode(amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), minAmounts[0], SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(staker)), IERC20(address(_FRAX)), _alice, 0, amount, data);

        vm.stopPrank();
    }

    function _deleverageImbalance(uint256 proportionWithdrawToken)
        internal
        returns (uint256[2] memory amountOuts, uint256 keptLPToken)
    {
        vm.startPrank(_alice);
        // deleverage
        uint256 amount = staker.balanceOf(_alice);
        uint256 maxBurnAmount;
        bytes memory data;
        {
            {
                uint256[2] memory minAmounts = [
                    (_METAPOOL.balances(0) * amount) / (asset.totalSupply()),
                    (_METAPOOL.balances(1) * amount) / (asset.totalSupply())
                ];
                // We do as if there were no slippage withdrawing in an imbalance manner vs a balance one and then
                // addd a slippage on the returned amount
                amountOuts = [
                    ((minAmounts[0] + minAmounts[1] * _DECIMAL_NORM_USDC) *
                        (10**9 - proportionWithdrawToken) *
                        SLIPPAGE_BPS) / (10**9 * _BPS),
                    ((minAmounts[0] / _DECIMAL_NORM_USDC + minAmounts[1]) * proportionWithdrawToken * SLIPPAGE_BPS) /
                        (10**9 * _BPS)
                ];
                // if we try to withdraw more than the curve balances -> rebalance
                uint256 curveBalanceFRAX = _METAPOOL.balances(0);
                uint256 curveBalanceUSDC = _METAPOOL.balances(1);
                if (curveBalanceFRAX < amountOuts[0]) {
                    amountOuts[0] = curveBalanceFRAX**99 / 100;
                } else if (curveBalanceUSDC < amountOuts[1]) {
                    amountOuts[1] = curveBalanceUSDC**99 / 100;
                }
            }
            maxBurnAmount = IMetaPool2(address(_METAPOOL)).calc_token_amount(amountOuts, false);

            bytes[] memory oneInchData = new bytes[](0);
            IERC20[] memory sweepTokens = new IERC20[](1);
            sweepTokens[0] = _USDC;
            bytes memory removeData = abi.encode(CurveRemovalType.imbalance, abi.encode(_bob, amountOuts));
            bytes memory swapData = abi.encode(amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), amountOuts[0], SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(staker)), IERC20(address(_FRAX)), _alice, 0, amount, data);

        vm.stopPrank();

        keptLPToken = amount - maxBurnAmount;
    }

    function _swapToImbalance(
        int128 coinSwapFrom,
        int128,
        uint256 swapAmount
    ) internal {
        vm.startPrank(_dylan);
        coinSwapFrom = int128(uint128(bound(uint256(uint128(coinSwapFrom)), 0, 1)));
        // do a swap to change the pool state and withdraw womething different than what has been deposited
        if (coinSwapFrom == 0) {
            swapAmount = bound(swapAmount, 10**18, 10**26);
            deal(address(_FRAX), address(_dylan), swapAmount);
            _FRAX.approve(address(_METAPOOL), type(uint256).max);
        } else {
            swapAmount = bound(swapAmount, 10**6, 10**14);
            deal(address(_USDC), address(_dylan), swapAmount);
            _USDC.approve(address(_METAPOOL), type(uint256).max);
        }
        _METAPOOL.exchange(coinSwapFrom, int128(1 - uint128(coinSwapFrom)), swapAmount, 0);

        vm.stopPrank();
    }

    function _assertCommonLeverage() internal {
        assertEq(staker.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(address(_alice)), 0);
        assertEq(asset.balanceOf(address(swapper)), 0);
        assertEq(_STAKEDAO_GAUGE.balanceOf(address(staker)), staker.totalSupply());
        assertEq(_USDT.balanceOf(_alice), 0);
        assertEq(_USDC.balanceOf(address(swapper)), 0);
        assertEq(_FRAX.balanceOf(address(swapper)), 0);
        assertEq(_USDT.balanceOf(address(swapper)), 0);
        assertEq(_USDC.balanceOf(address(staker)), 0);
        assertEq(_FRAX.balanceOf(address(staker)), 0);
        assertEq(_USDT.balanceOf(address(staker)), 0);
    }

    function _assertCommonDeleverage() internal {
        _assertCommonLeverage();
        assertEq(staker.balanceOf(_alice), 0);
        assertEq(_STAKEDAO_GAUGE.balanceOf(address(staker)), 0);
        assertEq(staker.totalSupply(), 0);
    }
}
