// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../BaseTest.test.sol";
import "../../../../contracts/interfaces/IBorrowStaker.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import { IMetaPool2 } from "../../../../contracts/interfaces/external/curve/IMetaPool2.sol";
import { IMetaPool3 } from "../../../../contracts/interfaces/external/curve/IMetaPool3.sol";
import "borrow/interfaces/coreModule/IStableMaster.sol";
import "borrow/interfaces/coreModule/IPoolManager.sol";
import "../../../../contracts/mock/MockTokenPermit.sol";
import { CurveRemovalType, SwapType, BaseLevSwapper, MockCurveLevSwapper2TokensWithBP, Swapper, IUniswapV3Router, IAngleRouterSidechain } from "../../../../contracts/mock/MockCurveLevSwapper2TokensWithBP.sol";
import { MockBorrowStaker } from "../../../../contracts/mock/MockBorrowStaker.sol";

// @dev Testing on Polygon
contract CurveLevSwapper3TokensWithBPBaseTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    address internal constant _ONE_INCH = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
    IUniswapV3Router internal constant _UNI_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAngleRouterSidechain internal constant _ANGLE_ROUTER =
        IAngleRouterSidechain(address(uint160(uint256(keccak256(abi.encodePacked("_fakeAngleRouter"))))));
    IERC20 public asset = IERC20(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);
    IERC20 internal constant _USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 internal constant _USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 internal constant _DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    IERC20 internal constant _LUSD = IERC20(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
    IERC20 internal constant _BPToken = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    uint256 internal constant _DECIMAL_NORM_USDC = 10**12;
    uint256 internal constant _DECIMAL_NORM_USDT = 10**12;
    uint256 internal constant _DECIMAL_NORM_LUSD = 10**0;

    IMetaPool2 internal constant _METAPOOL = IMetaPool2(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);
    IMetaPool3 internal constant _BPPOOL = IMetaPool3(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);

    uint256 internal constant _BPS = 10000;
    MockCurveLevSwapper2TokensWithBP public swapper;
    MockBorrowStaker public stakerImplementation;
    MockBorrowStaker public staker;
    uint256 public SLIPPAGE_BPS = 9900;

    function setUp() public override {
        super.setUp();

        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 16535240);
        vm.selectFork(_ethereum);

        // reset coreBorrow because the `makePersistent()` doens't work on my end
        coreBorrow = new MockCoreBorrow();
        coreBorrow.toggleGuardian(_GUARDIAN);
        coreBorrow.toggleGovernor(_GOVERNOR);

        stakerImplementation = new MockBorrowStaker();
        staker = MockBorrowStaker(
            deployUpgradeable(address(stakerImplementation), abi.encodeWithSelector(staker.setAsset.selector, asset))
        );
        staker.initialize(coreBorrow);

        swapper = new MockCurveLevSwapper2TokensWithBP(
            coreBorrow,
            _UNI_V3_ROUTER,
            _ONE_INCH,
            _ANGLE_ROUTER,
            IBorrowStaker(address(staker))
        );

        assertEq(staker.name(), "Angle Curve.fi Factory USD Metapool: Liquity Mock Staker");
        assertEq(staker.symbol(), "agstk-mock-LUSD3CRV-f");
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
        _DAI.approve(address(swapper), type(uint256).max);
        _LUSD.safeApprove(address(swapper), type(uint256).max);
        asset.safeApprove(address(swapper), type(uint256).max);
        vm.stopPrank();
    }

    function testLeverageNoUnderlyingTokensDeposited(uint256 amount) public {
        amount = bound(amount, 1, 10**27);
        console.log(address(swapper.angleStaker()));
        _depositDirect(amount);

        assertEq(staker.balanceOf(_alice), amount);
        assertEq(asset.balanceOf(address(staker)), amount);
        assertEq(staker.balanceOf(_alice), staker.totalSupply());
        assertEq(_DAI.balanceOf(_alice), 0);
        assertEq(_USDT.balanceOf(_alice), 0);
        assertEq(_USDC.balanceOf(_alice), 0);
        assertEq(_LUSD.balanceOf(_alice), 0);
        _assertCommonLeverage();
    }

    function testLeverageSuccess(uint256[4] memory amounts) public {
        uint256 minAmountOut = _depositSwapAndAddLiquidity(amounts, false);

        assertGe(staker.balanceOf(_alice), minAmountOut);
        assertGe(asset.balanceOf(address(staker)), minAmountOut);
        assertEq(staker.balanceOf(_alice), staker.totalSupply());
        assertEq(_DAI.balanceOf(_alice), 0);
        assertEq(_USDT.balanceOf(_alice), 0);
        assertEq(_USDC.balanceOf(_alice), 0);
        assertEq(_LUSD.balanceOf(_alice), 0);
        _assertCommonLeverage();
    }

    function testNoDepositDeleverageOneCoinToken0(uint256 amount) public {
        amount = bound(amount, 10**20, 10**24);
        int128 coinIndex = 1;
        IERC20 outToken = IERC20(address(_BPToken));

        _depositDirect(amount);
        uint256 minOneCoin = _deleverageOneCoin(coinIndex, outToken);

        assertEq(_LUSD.balanceOf(_alice), 0);
        assertGe(_BPToken.balanceOf(_alice), minOneCoin);
        _assertCommonDeleverage();
    }

    function testNoDepositDeleverageOneCoinToken1(uint256 amount) public {
        amount = bound(amount, 10**20, 10**24);
        int128 coinIndex = 0;
        IERC20 outToken = IERC20(address(_LUSD));

        _depositDirect(amount);
        uint256 minOneCoin = _deleverageOneCoin(coinIndex, outToken);

        assertEq(_BPToken.balanceOf(_alice), 0);
        assertGe(_LUSD.balanceOf(_alice), minOneCoin);
        _assertCommonDeleverage();
    }

    function testNoDepositDeleverageBalance(uint256 amount) public {
        amount = bound(amount, 10**20, 10**24);
        _depositDirect(amount);
        uint256[2] memory minAmounts = _deleverageBalance();

        assertGe(_LUSD.balanceOf(_alice), minAmounts[0]);
        assertGe(_BPToken.balanceOf(_alice), minAmounts[1]);
        _assertCommonDeleverage();
    }

    function testDeleverageOneCoinToken2(
        uint256[4] memory amounts,
        uint256 swapAmount,
        int128 coinSwap
    ) public {
        _depositSwapAndAddLiquidity(amounts, true);
        _swapToImbalance(coinSwap, coinSwap, swapAmount);

        int128 coinIndex = 0;
        IERC20 outToken = IERC20(address(_BPToken));
        uint256 minOneCoin = _deleverageOneCoin(coinIndex, outToken);

        assertEq(_LUSD.balanceOf(_alice), 0);
        assertGe(_BPToken.balanceOf(_alice), minOneCoin);
        _assertCommonDeleverage();
    }

    // function testDeleverageBalance(
    //     uint256 addLiquidityUSDC,
    //     uint256 addLiquidityFRAX,
    //     uint256 swapAmount,
    //     uint256 coinSwap
    // ) public {
    //     uint256 swappedFRAX = 10000 ether;
    //     uint256 swappedUSDT = 10000 * 10**6;
    //     addLiquidityUSDC = bound(addLiquidityUSDC, 0, 10**15);
    //     addLiquidityFRAX = bound(addLiquidityFRAX, 0, 10**27);

    //     deal(address(_USDC), address(_alice), addLiquidityUSDC);
    //     deal(address(_USDT), address(_alice), swappedUSDT);
    //     deal(address(_DAI), address(_alice), swappedFRAX + addLiquidityFRAX);
    //     vm.startPrank(_alice);

    //     bytes memory data;
    //     {
    //         // intermediary variables
    //         bytes[] memory oneInchData = new bytes[](2);
    //         // swap 10000 FRAX for USDC
    //         oneInchData[0] = abi.encode(
    //             address(_DAI),
    //             0,
    //             hex"e449022e00000000000000000000000000000000000000000000021e19e0c9bab2400000000000000000000000000000000000000000000000000000000000024dc9bbaa000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000010000000000000000000000009a834b70c07c81a9fcd6f22e842bf002fbffbe4dcfee7c08"
    //         );
    //         // swap 10000 USDT for USDC
    //         oneInchData[1] = abi.encode(
    //             address(_USDT),
    //             0,
    //             hex"e449022e00000000000000000000000000000000000000000000000000000002540be400000000000000000000000000000000000000000000000000000000024e089f88000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000018000000000000000000000003416cf6c708da44db2624d63ea0aaef7113527c6cfee7c08"
    //         );
    //         uint256 minAmountOut;
    //         {
    //             uint256 lowerBoundSwap = (((addLiquidityUSDC + swappedUSDT + swappedFRAX / _DECIMAL_NORM_USDC) *
    //                 SLIPPAGE_BPS) / _BPS);
    //             minAmountOut =
    //                 (IMetaPool2(address(_METAPOOL)).calc_token_amount([addLiquidityFRAX, lowerBoundSwap], true) *
    //                     SLIPPAGE_BPS) /
    //                 _BPS;
    //         }

    //         bytes memory addData;
    //         bytes memory swapData = abi.encode(oneInchData, addData);
    //         bytes memory leverageData = abi.encode(true, _alice, swapData);
    //         data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);
    //     }
    //     // we first need to send the tokens before hand, you should always use the swapper
    //     // in another tx to not losse your funds by front running
    //     _USDC.transfer(address(swapper), addLiquidityUSDC);
    //     _DAI.transfer(address(swapper), swappedFRAX + addLiquidityFRAX);
    //     _USDT.safeTransfer(address(swapper), swappedUSDT);
    //     swapper.swap(IERC20(address(_USDC)), IERC20(address(staker)), _alice, 0, addLiquidityUSDC, data);

    //     vm.stopPrank();
    //     vm.startPrank(_dylan);
    //     // do a swap to change the pool state and withdraw womething different than what has been deposited
    //     coinSwap = coinSwap % 2;
    //     if (coinSwap == 0) {
    //         swapAmount = bound(swapAmount, 10**18, 10**26);
    //         deal(address(_DAI), address(_dylan), swapAmount);
    //         _DAI.approve(address(_METAPOOL), type(uint256).max);
    //     } else {
    //         swapAmount = bound(swapAmount, 10**6, 10**14);
    //         deal(address(_USDC), address(_dylan), swapAmount);
    //         _USDC.approve(address(_METAPOOL), type(uint256).max);
    //     }
    //     _METAPOOL.exchange(int128(uint128(coinSwap)), int128(1 - uint128(coinSwap)), swapAmount, 0);

    //     vm.stopPrank();
    //     vm.startPrank(_alice);
    //     // deleverage
    //     uint256 amount = staker.balanceOf(_alice);
    //     uint256[2] memory minAmounts;
    //     {
    //         bytes[] memory oneInchData = new bytes[](0);
    //         IERC20[] memory sweepTokens = new IERC20[](1);
    //         sweepTokens[0] = _USDC;
    //         minAmounts = [
    //             (_METAPOOL.balances(0) * amount * SLIPPAGE_BPS) / (_BPS * asset.totalSupply()),
    //             (_METAPOOL.balances(1) * amount * SLIPPAGE_BPS) / (_BPS * asset.totalSupply())
    //         ];
    //         bytes memory removeData = abi.encode(CurveRemovalType.balance, abi.encode(minAmounts));
    //         bytes memory swapData = abi.encode(amount, sweepTokens, oneInchData, removeData);
    //         bytes memory leverageData = abi.encode(false, _alice, swapData);
    //         data = abi.encode(address(0), minAmounts[0], SwapType.Leverage, leverageData);
    //     }
    //     staker.transfer(address(swapper), amount);
    //     swapper.swap(IERC20(address(staker)), IERC20(address(_DAI)), _alice, 0, amount, data);

    //     vm.stopPrank();

    //     assertGe(_USDC.balanceOf(_alice), minAmounts[1]);
    //     assertGe(_DAI.balanceOf(_alice), minAmounts[0]);
    //     assertEq(staker.balanceOf(address(swapper)), 0);
    //     assertEq(staker.balanceOf(_alice), 0);
    //     assertEq(asset.balanceOf(address(_alice)), 0);
    //     assertEq(asset.balanceOf(address(swapper)), 0);
    //     assertEq(asset.balanceOf(address(staker)), 0);
    //     assertEq(_USDT.balanceOf(_alice), 0);
    //     assertEq(_USDC.balanceOf(address(swapper)), 0);
    //     assertEq(_DAI.balanceOf(address(swapper)), 0);
    //     assertEq(_USDT.balanceOf(address(swapper)), 0);
    //     assertEq(_USDC.balanceOf(address(staker)), 0);
    //     assertEq(_DAI.balanceOf(address(staker)), 0);
    //     assertEq(_USDT.balanceOf(address(staker)), 0);
    // }

    // // remove_liquidity_imbalance doesn't exist on this pool just let it here for future 3 tokens with BP pools
    // function testNoDepositDeleverageImbalance(
    //     uint256 amount,
    //     uint256 proportionWithdrawToken1,
    //     uint256 proportionWithdrawToken2,
    //     uint256 coinSwap,
    //     uint256 swapAmount
    // ) public {
    //     amount = bound(amount, 10**20, 10**24);
    //     proportionWithdrawToken1 = bound(proportionWithdrawToken1, 0, 10**9);
    //     proportionWithdrawToken2 = bound(proportionWithdrawToken2, 0, 10**9 - proportionWithdrawToken1);

    //     _depositDirect(amount);
    //     // _swapToImbalance(1, 2, swapAmount);

    //     vm.startPrank(_alice);
    //     // deleverage
    //     amount = staker.balanceOf(_alice);
    //     uint256[3] memory amountOuts;
    //     uint256 maxBurnAmount;
    //     bytes memory data;
    //     {
    //         {
    //             uint256[3] memory minAmounts = [
    //                 (_METAPOOL.balances(0) * amount) / (asset.totalSupply()),
    //                 (_METAPOOL.balances(1) * amount) / (asset.totalSupply()),
    //                 (_METAPOOL.balances(2) * amount) / (asset.totalSupply())
    //             ];
    //             // We do as if there were no slippage withdrawing in an imbalance manner vs a balance one and then
    //             // addd a slippage on the returned amount
    //             amountOuts = [
    //                 ((minAmounts[0] + minAmounts[1] * _DECIMAL_NORM_WBTC + minAmounts[1]) *
    //                     (10**9 - proportionWithdrawToken1 - proportionWithdrawToken2) *
    //                     SLIPPAGE_BPS) / (10**9 * _BPS),
    //                 ((minAmounts[0] / _DECIMAL_NORM_WBTC + minAmounts[1] + minAmounts[1] / _DECIMAL_NORM_WBTC) *
    //                     proportionWithdrawToken1 *
    //                     SLIPPAGE_BPS) / (10**9 * _BPS),
    //                 ((minAmounts[0] + minAmounts[1] * _DECIMAL_NORM_WBTC + minAmounts[1]) *
    //                     proportionWithdrawToken2 *
    //                     SLIPPAGE_BPS) / (10**9 * _BPS)
    //             ];
    //             // if we try to withdraw more than the curve balances -> rebalance
    //             uint256 curveBalanceAave = _METAPOOL.balances(0);
    //             uint256 curveBalanceWBTC = _METAPOOL.balances(1);
    //             uint256 curveBalanceWETH = _METAPOOL.balances(1);
    //             if (curveBalanceAave < amountOuts[0]) {
    //                 amountOuts[0] = curveBalanceAave**99 / 100;
    //             } else if (curveBalanceWBTC < amountOuts[1]) {
    //                 amountOuts[1] = curveBalanceWBTC**99 / 100;
    //             } else if (curveBalanceWETH < amountOuts[2]) {
    //                 amountOuts[2] = curveBalanceWETH**99 / 100;
    //             }
    //         }
    //         maxBurnAmount = IMetaPool3(address(_METAPOOL)).calc_token_amount(amountOuts, false);

    //         bytes[] memory oneInchData = new bytes[](0);
    //         IERC20[] memory sweepTokens = new IERC20[](2);
    //         sweepTokens[0] = _amWBTC;
    //         sweepTokens[1] = _amWETH;
    //         bytes memory removeData = abi.encode(CurveRemovalType.imbalance, false, abi.encode(_bob, amountOuts));
    //         bytes memory swapData = abi.encode(amount, sweepTokens, oneInchData, removeData);
    //         bytes memory leverageData = abi.encode(false, _alice, swapData);
    //         data = abi.encode(address(0), amountOuts[0], SwapType.Leverage, leverageData);
    //     }
    //     staker.transfer(address(swapper), amount);
    //     swapper.swap(IERC20(address(staker)), IERC20(address(_AaveBPToken)), _alice, 0, amount, data);

    //     vm.stopPrank();

    //     assertGe(_USDC.balanceOf(_alice), amountOuts[1]);
    //     assertGe(_DAI.balanceOf(_alice), amountOuts[0]);
    //     assertLe(staker.balanceOf(_bob), amount - maxBurnAmount);
    //     assertLe(staker.totalSupply(), amount - maxBurnAmount);
    //     assertLe(asset.balanceOf(address(staker)), amount - maxBurnAmount);
    //     assertEq(staker.balanceOf(_alice), 0);
    //     assertEq(staker.balanceOf(address(swapper)), 0);
    //     assertEq(asset.balanceOf(address(_alice)), 0);
    //     assertEq(asset.balanceOf(address(swapper)), 0);
    //     assertEq(_USDT.balanceOf(_alice), 0);
    //     assertEq(_USDC.balanceOf(address(swapper)), 0);
    //     assertEq(_DAI.balanceOf(address(swapper)), 0);
    //     assertEq(_USDT.balanceOf(address(swapper)), 0);
    //     assertEq(_USDC.balanceOf(address(staker)), 0);
    //     assertEq(_DAI.balanceOf(address(staker)), 0);
    //     assertEq(_USDT.balanceOf(address(staker)), 0);
    // }

    // ============================== HELPER FUNCTIONS =============================

    function _depositDirect(uint256 amount) internal {
        deal(address(asset), address(_alice), amount);
        vm.startPrank(_alice);
        // intermediary variables
        bytes memory data;
        {
            bytes[] memory oneInchData = new bytes[](0);

            bytes memory addData = abi.encode(false);
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

    function _depositSwapAndAddLiquidity(uint256[4] memory amounts, bool doSwaps)
        internal
        returns (uint256 minAmountOut)
    {
        // DAI - USDC - USDT - LUSD
        amounts[0] = bound(amounts[0], 1, 10**(18 + 6));
        amounts[1] = bound(amounts[1], 1, 10**(6 + 6));
        amounts[2] = bound(amounts[2], 1, 10**(6 + 6));
        amounts[3] = bound(amounts[3], 1, 10**(18 + 6));

        uint256 swappedDAI = doSwaps ? 100000 ether : 0;
        uint256 swappedUSDT = doSwaps ? 100000 * 10**6 : 0;
        uint256 swappedUSDC = doSwaps ? 100000 * 10**6 : 0;
        uint256 swappedLUSD = doSwaps ? 100000 ether : 0;

        // deal(address(_DAI), address(_alice), swappedDAI + amounts[0]);
        // deal(address(_USDC), address(_alice), swappedUSDC + amounts[1]);
        // deal(address(_USDT), address(_alice), swappedUSDT + amounts[2]);
        deal(address(_LUSD), address(_alice), swappedLUSD + amounts[3]);

        vm.startPrank(_alice);
        // intermediary variables

        bytes[] memory oneInchData;

        oneInchData = new bytes[](0);
        {
            uint256 lowerBoundLPBP = (IMetaPool3(address(_BPPOOL)).calc_token_amount(
                [
                    (swappedDAI * SLIPPAGE_BPS) / _BPS + amounts[0],
                    (swappedUSDC * SLIPPAGE_BPS) / _BPS + amounts[1],
                    (swappedUSDT * SLIPPAGE_BPS) / _BPS + amounts[2]
                ],
                true
            ) * SLIPPAGE_BPS) / _BPS;
            minAmountOut =
                (IMetaPool2(address(_METAPOOL)).calc_token_amount([amounts[3], lowerBoundLPBP], true) * SLIPPAGE_BPS) /
                _BPS;
        }

        bytes memory addData = abi.encode(false);
        bytes memory swapData = abi.encode(oneInchData, addData);
        bytes memory leverageData = abi.encode(true, _alice, swapData);
        bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

        // we first need to send the tokens before hand, you should always use the swapper
        // in another tx to not losse your funds by front running
        // _DAI.transfer(address(swapper), swappedDAI);
        // _USDC.transfer(address(swapper), swappedUSDC);
        // _USDT.safeTransfer(address(swapper), swappedUSDT);
        // _DAI.safeTransfer(address(swapper), amounts[0]);
        // _USDC.safeTransfer(address(swapper), amounts[1]);
        // _USDT.safeTransfer(address(swapper), amounts[2]);
        _LUSD.safeTransfer(address(swapper), amounts[3]);
        swapper.swap(IERC20(address(_USDC)), IERC20(address(staker)), _alice, 0, swappedUSDC, data);

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
            bytes memory removeData = abi.encode(CurveRemovalType.oneCoin, false, abi.encode(coinIndex, minOneCoin));
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
            sweepTokens[0] = _LUSD;
            minAmounts = [
                (_METAPOOL.balances(0) * amount * SLIPPAGE_BPS) / (_BPS * asset.totalSupply()),
                (_METAPOOL.balances(1) * amount * SLIPPAGE_BPS) / (_BPS * asset.totalSupply())
            ];
            bytes memory removeData = abi.encode(CurveRemovalType.balance, false, abi.encode(minAmounts));
            bytes memory swapData = abi.encode(amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), minAmounts[0], SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(staker)), IERC20(address(_BPToken)), _alice, 0, amount, data);

        vm.stopPrank();
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
            deal(address(_BPToken), address(_dylan), swapAmount);
            _BPToken.approve(address(_METAPOOL), type(uint256).max);
        } else {
            swapAmount = bound(swapAmount, 10**18, 10**(18 + 8));
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
        assertEq(asset.balanceOf(address(staker)), staker.totalSupply());
        assertEq(_USDT.balanceOf(_alice), 0);
        assertEq(_USDC.balanceOf(address(swapper)), 0);
        assertEq(_LUSD.balanceOf(address(swapper)), 0);
        assertEq(_DAI.balanceOf(address(swapper)), 0);
        assertEq(_USDT.balanceOf(address(swapper)), 0);
        assertEq(_USDC.balanceOf(address(staker)), 0);
        assertEq(_LUSD.balanceOf(address(staker)), 0);
        assertEq(_USDT.balanceOf(address(staker)), 0);
        assertEq(_DAI.balanceOf(address(staker)), 0);
    }

    function _assertCommonDeleverage() internal {
        _assertCommonLeverage();
        assertEq(staker.balanceOf(_alice), 0);
        assertEq(asset.balanceOf(address(staker)), 0);
        assertEq(staker.totalSupply(), 0);
    }
}
