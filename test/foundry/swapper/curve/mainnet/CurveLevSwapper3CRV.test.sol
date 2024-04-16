// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../../BaseTest.test.sol";
import "borrow-staked/interfaces/IBorrowStaker.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow-staked/interfaces/external/curve/IMetaPool3.sol";
import "borrow/interfaces/coreModule/IStableMaster.sol";
import "borrow/interfaces/coreModule/IPoolManager.sol";
import "borrow-staked/mock/MockTokenPermit.sol";
import { CurveRemovalType, SwapType, BaseLevSwapper, MockCurveLevSwapper3CRV, Swapper, IUniswapV3Router, IAngleRouterSidechain } from "borrow-staked/mock/implementations/swapper/mainnet/MockCurveLevSwapper3CRV.sol";
import { MockBorrowStaker } from "borrow-staked/mock/MockBorrowStaker.sol";

//solhint-disable
interface ILendingPool {
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
}
// @dev Testing on Polygon
contract CurveLevSwapper3CRVTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    address internal constant _ONE_INCH = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
    IUniswapV3Router internal constant _UNI_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAngleRouterSidechain internal constant _ANGLE_ROUTER =
        IAngleRouterSidechain(address(uint160(uint256(keccak256(abi.encodePacked("_fakeAngleRouter"))))));

    IERC20 public asset = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    IERC20 internal constant _USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 internal constant _USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 internal constant _DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20[3] internal listTokens;
    uint256 internal constant _DECIMAL_NORM_USDC = 10 ** 12;
    uint256 internal constant _DECIMAL_NORM_USDT = 10 ** 12;

    IMetaPool3 internal constant _METAPOOL = IMetaPool3(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);

    uint256 internal constant _BPS = 10000;
    MockCurveLevSwapper3CRV public swapper;
    MockBorrowStaker public stakerImplementation;
    MockBorrowStaker public staker;
    IERC20 public tokenHolder;
    uint256 public SLIPPAGE_BPS = 9800;

    function setUp() public virtual override {
        super.setUp();

        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 16535240);
        vm.selectFork(_ethereum);

        listTokens = [_DAI, _USDC, _USDT];
        // reset coreBorrow because the `makePersistent()` doens't work on my end
        coreBorrow = new MockCoreBorrow();
        coreBorrow.toggleGuardian(_GUARDIAN);
        coreBorrow.toggleGovernor(_GOVERNOR);

        tokenHolder = asset;

        stakerImplementation = new MockBorrowStaker();
        staker = MockBorrowStaker(
            deployUpgradeable(address(stakerImplementation), abi.encodeWithSelector(staker.setAsset.selector, asset))
        );
        staker.initialize(coreBorrow);

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

        vm.startPrank(_alice);
        _USDC.approve(address(swapper), type(uint256).max);
        _USDT.safeIncreaseAllowance(address(swapper), type(uint256).max);
        _DAI.approve(address(swapper), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(_dylan);
        _USDC.approve(address(swapper), type(uint256).max);
        _USDT.safeIncreaseAllowance(address(swapper), type(uint256).max);
        _DAI.approve(address(swapper), type(uint256).max);
        vm.stopPrank();
    }

    function testInitialise() public virtual {
        assertEq(staker.name(), "Angle Curve.fi DAI/USDC/USDT Mock Staker");
        assertEq(staker.symbol(), "agstk-mock-3Crv");
        assertEq(staker.decimals(), 18);
    }

    function testLeverageNoUnderlyingTokensDeposited(uint256 amount) public {
        amount = bound(amount, 1, 10 ** 27);

        _depositDirect(amount);

        assertEq(staker.balanceOf(_alice), amount);
        assertEq(tokenHolder.balanceOf(address(staker)), amount);
        assertEq(staker.balanceOf(_alice), staker.totalSupply());
        _assertCommonLeverage();
    }

    function testLeverageSuccess(uint256[3] memory amounts) public {
        uint256 minAmountOut = _depositSwapAndAddLiquidity(amounts);

        assertGe(staker.balanceOf(_alice), minAmountOut);
        assertGe(tokenHolder.balanceOf(address(staker)), minAmountOut);
        assertEq(staker.balanceOf(_alice), staker.totalSupply());
        _assertCommonLeverage();
    }

    function testNoDepositDeleverageCollatAndOneCoinToken1(uint256 amount, uint256 propToRemove) public {
        amount = bound(amount, BASE_PARAMS, 10 ** 24);
        propToRemove = bound(propToRemove, 1, BASE_PARAMS);
        int128 coinIndex = 1;
        IERC20 outToken = IERC20(address(_USDC));

        _depositDirect(amount);
        (uint256 minOneCoin, uint256 keptCollateral) = _deleverageCollateralAndOneCoin(
            coinIndex,
            propToRemove,
            outToken
        );

        assertGe(_USDC.balanceOf(_alice), minOneCoin);
        assertEq(_USDT.balanceOf(_alice), 0);
        assertEq(_DAI.balanceOf(_alice), 0);
        assertEq(asset.balanceOf(address(_alice)), keptCollateral);
    }

    function testNoDepositDeleverageBalance(uint256 amount) public {
        amount = bound(amount, 1, 10 ** 24);
        _depositDirect(amount);
        uint256[3] memory minAmounts = _deleverageBalance();

        assertGe(_DAI.balanceOf(_alice), minAmounts[0]);
        assertGe(_USDC.balanceOf(_alice), minAmounts[1]);
        assertGe(_USDT.balanceOf(_alice), minAmounts[2]);
        _assertCommonDeleverage();
    }

    function testDeleverageOneCoinToken(
        uint256[3] memory amounts,
        uint256 swapAmount,
        uint256 coinIndex,
        int128 coinSwapFrom,
        int128 coinSwapTo
    ) public {
        coinIndex = bound(coinIndex, 0, 2);
        _depositSwapAndAddLiquidity(amounts);

        coinSwapFrom = int128(uint128(bound(uint256(uint128(coinSwapFrom)), 0, 2)));
        coinSwapTo = int128(uint128(bound(uint256(uint128(coinSwapTo)), 0, 2)));

        if (coinSwapTo == coinSwapFrom && coinSwapTo < 2) coinSwapTo += 1;
        else if (coinSwapTo == coinSwapFrom) coinSwapTo -= 1;
        _swapToImbalance(coinSwapFrom, coinSwapTo, swapAmount);

        IERC20 outToken = listTokens[coinIndex];

        uint256 minOneCoin = _deleverageOneCoin(int128(uint128(coinIndex)), outToken);

        for (uint256 i; i < listTokens.length; i++) {
            if (i == coinIndex) assertGe(listTokens[i].balanceOf(_alice), minOneCoin);
            else assertEq(listTokens[i].balanceOf(_alice), 0);
        }
        _assertCommonDeleverage();
    }

    function testDeleverageBalance(uint256[3] memory amounts, int128 coinSwapFrom, int128 coinSwapTo) public {
        _depositSwapAndAddLiquidity(amounts);

        coinSwapFrom = int128(uint128(bound(uint256(uint128(coinSwapFrom)), 0, 2)));
        coinSwapTo = int128(uint128(bound(uint256(uint128(coinSwapTo)), 0, 2)));

        if (coinSwapTo == coinSwapFrom && coinSwapTo < 2) coinSwapTo += 1;
        else if (coinSwapTo == coinSwapFrom) coinSwapTo -= 1;

        uint256[3] memory minAmounts = _deleverageBalance();

        assertGe(_DAI.balanceOf(_alice), minAmounts[0]);
        assertGe(_USDC.balanceOf(_alice), minAmounts[1]);
        assertGe(_USDT.balanceOf(_alice), minAmounts[2]);
        _assertCommonDeleverage();
    }

    function testDeleverageImbalance(
        uint256[3] memory amounts,
        uint256 swapAmount,
        int128 coinSwapFrom,
        int128 coinSwapTo,
        uint256 proportionWithdrawToken1,
        uint256 proportionWithdrawToken2
    ) public {
        proportionWithdrawToken1 = bound(proportionWithdrawToken1, 0, 10 ** 9);
        proportionWithdrawToken2 = bound(proportionWithdrawToken2, 0, 10 ** 9 - proportionWithdrawToken1);

        _depositSwapAndAddLiquidity(amounts);

        coinSwapFrom = int128(uint128(bound(uint256(uint128(coinSwapFrom)), 0, 2)));
        coinSwapTo = int128(uint128(bound(uint256(uint128(coinSwapTo)), 0, 2)));

        if (coinSwapTo == coinSwapFrom && coinSwapTo < 2) coinSwapTo += 1;
        else if (coinSwapTo == coinSwapFrom) coinSwapTo -= 1;
        _swapToImbalance(coinSwapFrom, coinSwapTo, swapAmount);

        (uint256[3] memory amountOut, uint256 keptLPToken) = _deleverageImbalance(
            proportionWithdrawToken1,
            proportionWithdrawToken2
        );
        if (amountOut[0] < 10 wei && amountOut[1] < 10 wei && amountOut[2] < 10 wei) return;

        assertEq(_DAI.balanceOf(_alice), amountOut[0]);
        assertEq(_USDC.balanceOf(_alice), amountOut[1]);
        assertEq(_USDT.balanceOf(_alice), amountOut[2]);
        assertEq(_DAI.balanceOf(_bob), 0);
        assertEq(_USDC.balanceOf(_bob), 0);
        assertEq(_USDT.balanceOf(_bob), 0);
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
        bytes memory data;
        {
            bytes[] memory oneInchData = new bytes[](0);

            bytes memory addData;
            bytes memory swapData = abi.encode(oneInchData, addData);
            bytes memory leverageData = abi.encode(true, _alice, swapData);
            data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);
        }
        // we first need to send the tokens before hand, you should always use the swapper
        // in another tx to not losse your funds by front running
        asset.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(asset)), IERC20(address(staker)), _alice, 0, amount, data);

        vm.stopPrank();
    }

    function _depositSwapAndAddLiquidity(uint256[3] memory amounts) internal returns (uint256 minAmountOut) {
        // DAI - USDC - USDT
        amounts[0] = bound(amounts[0], 1, 10 ** 24);
        amounts[1] = bound(amounts[1], 1, 10 ** 12);
        amounts[2] = bound(amounts[2], 1, 10 ** 12);

        deal(address(_DAI), address(_alice), amounts[0]);
        deal(address(_USDC), address(_alice), amounts[1]);
        deal(address(_USDT), address(_alice), amounts[2]);

        vm.startPrank(_alice);
        // intermediary variables
        bytes[] memory oneInchData;
        oneInchData = new bytes[](0);

        {
            minAmountOut =
                (IMetaPool3(address(_METAPOOL)).calc_token_amount([amounts[0], amounts[1], amounts[2]], true) *
                    SLIPPAGE_BPS) /
                _BPS;
        }

        bytes memory addData;
        bytes memory swapData = abi.encode(oneInchData, addData);
        bytes memory leverageData = abi.encode(true, _alice, swapData);
        bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

        // rounding when calling deposit on Aave, it can consider we have less than what we just deposited
        _DAI.safeTransfer(address(swapper), amounts[0]);
        _USDC.safeTransfer(address(swapper), amounts[1]);
        _USDT.safeTransfer(address(swapper), amounts[2]);
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
            minOneCoin = (_METAPOOL.calc_withdraw_one_coin(amount, coinIndex) * SLIPPAGE_BPS) / _BPS;
            bytes memory removeData = abi.encode(CurveRemovalType.oneCoin, abi.encode(coinIndex, minOneCoin));
            bytes memory swapData = abi.encode(amount, amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), minOneCoin, SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(staker)), outToken, _alice, 0, amount, data);

        vm.stopPrank();

        return minOneCoin;
    }

    function _deleverageCollateralAndOneCoin(
        int128 coinIndex,
        uint256 propToRemove,
        IERC20 outToken
    ) internal returns (uint256, uint256) {
        vm.startPrank(_alice);
        // deleverage
        uint256 amount = staker.balanceOf(_alice);
        uint256 amountToRemove = (amount * propToRemove) / BASE_PARAMS;
        uint256 minOneCoin;
        bytes memory data;
        {
            bytes[] memory oneInchData = new bytes[](0);
            IERC20[] memory sweepTokens = new IERC20[](1);
            sweepTokens[0] = asset;
            minOneCoin = (_METAPOOL.calc_withdraw_one_coin(amountToRemove, coinIndex) * SLIPPAGE_BPS) / _BPS;
            bytes memory removeData = abi.encode(CurveRemovalType.oneCoin, abi.encode(coinIndex, minOneCoin));
            bytes memory swapData = abi.encode(amount, amountToRemove, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), minOneCoin, SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(staker)), outToken, _alice, 0, amount, data);

        vm.stopPrank();

        return (minOneCoin, amount - amountToRemove);
    }

    function _deleverageBalance() internal returns (uint256[3] memory minAmounts) {
        vm.startPrank(_alice);
        // deleverage
        uint256 amount = staker.balanceOf(_alice);
        bytes memory data;
        {
            bytes[] memory oneInchData = new bytes[](0);
            IERC20[] memory sweepTokens = new IERC20[](2);
            sweepTokens[0] = _USDT;
            sweepTokens[1] = _DAI;
            minAmounts = [
                (_METAPOOL.balances(0) * amount * SLIPPAGE_BPS) / (_BPS * asset.totalSupply()),
                (_METAPOOL.balances(1) * amount * SLIPPAGE_BPS) / (_BPS * asset.totalSupply()),
                (_METAPOOL.balances(2) * amount * SLIPPAGE_BPS) / (_BPS * asset.totalSupply())
            ];
            bytes memory removeData = abi.encode(CurveRemovalType.balance, abi.encode(minAmounts));
            bytes memory swapData = abi.encode(amount, amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), minAmounts[1], SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(staker)), IERC20(address(_USDC)), _alice, 0, amount, data);

        vm.stopPrank();
    }

    function _deleverageImbalance(
        uint256 proportionWithdrawToken1,
        uint256 proportionWithdrawToken2
    ) internal returns (uint256[3] memory amountOuts, uint256 keptLPToken) {
        vm.startPrank(_alice);
        // deleverage
        uint256 amount = staker.balanceOf(_alice);
        uint256 maxBurnAmount;
        bytes memory data;
        {
            {
                uint256[3] memory minAmounts = [
                    (_METAPOOL.balances(0) * amount) / (asset.totalSupply()),
                    (_METAPOOL.balances(1) * amount) / (asset.totalSupply()),
                    (_METAPOOL.balances(2) * amount) / (asset.totalSupply())
                ];
                // We do as if there were no slippage withdrawing in an imbalance manner vs a balance one and then
                // addd a slippage on the returned amount
                amountOuts = [
                    ((minAmounts[0] + minAmounts[1] * _DECIMAL_NORM_USDC + minAmounts[2] * _DECIMAL_NORM_USDT) *
                        (10 ** 9 - proportionWithdrawToken1 - proportionWithdrawToken2) *
                        SLIPPAGE_BPS) / (10 ** 9 * _BPS),
                    ((minAmounts[0] / _DECIMAL_NORM_USDC + minAmounts[1] + minAmounts[2]) *
                        proportionWithdrawToken1 *
                        SLIPPAGE_BPS) / (10 ** 9 * _BPS),
                    ((minAmounts[0] / _DECIMAL_NORM_USDC + minAmounts[1] + minAmounts[2]) *
                        proportionWithdrawToken2 *
                        SLIPPAGE_BPS) / (10 ** 9 * _BPS)
                ];
                // if we try to withdraw more than the curve balances -> rebalance
                uint256 curveBalanceDAI = _METAPOOL.balances(0);
                uint256 curveBalanceUSDC = _METAPOOL.balances(1);
                uint256 curveBalanceUSDT = _METAPOOL.balances(2);
                if (curveBalanceDAI < amountOuts[0]) {
                    amountOuts[0] = curveBalanceDAI ** 99 / 100;
                } else if (curveBalanceUSDC < amountOuts[1]) {
                    amountOuts[1] = curveBalanceUSDC ** 99 / 100;
                } else if (curveBalanceUSDT < amountOuts[2]) {
                    amountOuts[2] = curveBalanceUSDT ** 99 / 100;
                }
                if (amountOuts[0] < 10 wei && amountOuts[1] < 10 wei && amountOuts[2] < 10 wei) return (amountOuts, 0);
            }
            maxBurnAmount = IMetaPool3(address(_METAPOOL)).calc_token_amount(amountOuts, false);
            // Again there can be rounding issues on Aave because of the index value
            uint256 minAmountOut = amountOuts[1] > 5 wei ? amountOuts[1] - 5 wei : 0;

            bytes[] memory oneInchData = new bytes[](0);
            IERC20[] memory sweepTokens = new IERC20[](2);
            sweepTokens[0] = _USDT;
            sweepTokens[1] = _DAI;
            bytes memory removeData = abi.encode(CurveRemovalType.imbalance, abi.encode(_bob, amountOuts));
            bytes memory swapData = abi.encode(amount, amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), minAmountOut, SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(staker)), IERC20(address(_USDC)), _alice, 0, amount, data);

        vm.stopPrank();

        keptLPToken = amount - maxBurnAmount;
    }

    function _swapToImbalance(int128 coinSwapFrom, int128 coinSwapTo, uint256 swapAmount) internal {
        // do a swap to change the pool state and withdraw womething different than what has been deposited
        coinSwapFrom = coinSwapFrom % 3;
        coinSwapTo = coinSwapTo % 3;
        vm.startPrank(_dylan);
        if (coinSwapFrom == 0) {
            swapAmount = bound(swapAmount, 10 ** 18, 10 ** 23);
            deal(address(_DAI), address(_dylan), swapAmount);
            _DAI.approve(address(_METAPOOL), type(uint256).max);
        } else if (coinSwapFrom == 1) {
            swapAmount = bound(swapAmount, 10 ** 6, 10 ** 11);
            deal(address(_USDC), address(_dylan), swapAmount);
            IERC20(address(_USDC)).approve(address(_METAPOOL), type(uint256).max);
        } else {
            swapAmount = bound(swapAmount, 10 ** 6, 10 ** 11);
            deal(address(_USDT), address(_dylan), swapAmount);
            IERC20(address(_USDT)).safeApprove(address(_METAPOOL), type(uint256).max);
        }
        _METAPOOL.exchange(coinSwapFrom, coinSwapTo, swapAmount, 0);

        vm.stopPrank();
    }

    function _assertCommonLeverage() internal {
        assertEq(staker.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(address(_alice)), 0);
        assertEq(asset.balanceOf(address(swapper)), 0);
        assertEq(tokenHolder.balanceOf(address(staker)), staker.totalSupply());
        assertEq(_USDC.balanceOf(address(swapper)), 0);
        assertEq(_DAI.balanceOf(address(swapper)), 0);
        assertEq(_USDT.balanceOf(address(swapper)), 0);
        assertEq(_USDC.balanceOf(address(staker)), 0);
        assertEq(_DAI.balanceOf(address(staker)), 0);
        assertEq(_USDT.balanceOf(address(staker)), 0);
    }

    function _assertCommonDeleverage() internal {
        _assertCommonLeverage();
        assertEq(staker.balanceOf(_alice), 0);
        assertEq(tokenHolder.balanceOf(address(staker)), 0);
        assertEq(staker.totalSupply(), 0);
    }
}
