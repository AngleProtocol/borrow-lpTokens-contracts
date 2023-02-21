// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../BaseTest.test.sol";
import "../../../../contracts/interfaces/IBorrowStaker.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "../../../../contracts/interfaces/external/curve/IMetaPool2.sol";
import "borrow/interfaces/coreModule/IStableMaster.sol";
import "borrow/interfaces/coreModule/IPoolManager.sol";
import "../../../../contracts/mock/MockTokenPermit.sol";
import { CurveRemovalType, SwapType, BaseLevSwapper, MockCurveLevSwapperLUSDv3CRV, Swapper, IUniswapV3Router, IAngleRouterSidechain } from "../../../../contracts/mock/implementations/swapper/mainnet/MockCurveLevSwapperLUSDv3CRV.sol";
import "../../swapper/curve/CurveLevSwapper2TokensBaseTest.test.sol";
import { ConvexLUSDv3CRVStaker } from "../../../../contracts/staker/curve/implementations/mainnet/pools/ConvexLUSDv3CRVStaker.sol";

contract ConvexLUSDv3CRVTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    address internal constant _ONE_INCH = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
    IUniswapV3Router internal constant _UNI_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAngleRouterSidechain internal constant _ANGLE_ROUTER =
        IAngleRouterSidechain(address(uint160(uint256(keccak256(abi.encodePacked("_fakeAngleRouter"))))));
    IERC20 public asset = IERC20(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);
    IERC20 internal constant _LUSD = IERC20(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);
    IERC20 internal constant _3CRV = IERC20(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    IMetaPool2 internal constant _METAPOOL = IMetaPool2(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);
    IERC20 internal constant _BASE_REWARD_POOL = IERC20(0x2ad92A7aE036a038ff02B96c88de868ddf3f8190);

    IERC20[2] internal listTokens;
    uint256 internal constant _BPS = 10000;
    MockCurveLevSwapperLUSDv3CRV public swapper;
    ConvexLUSDv3CRVStaker public stakerImplementation;
    ConvexLUSDv3CRVStaker public staker;
    IERC20 public tokenHolder;
    uint256 public SLIPPAGE_BPS = 9900;

    function setUp() public virtual override {
        super.setUp();

        _ethereum = vm.createFork(vm.envString("ETH_NODE_URI_MAINNET"), 15824909);
        vm.selectFork(_ethereum);

        // reset coreBorrow because the `makePersistent()` doens't work on my end
        coreBorrow = new MockCoreBorrow();
        coreBorrow.toggleGuardian(_GUARDIAN);
        coreBorrow.toggleGovernor(_GOVERNOR);
        tokenHolder = IERC20(address(_BASE_REWARD_POOL));
        listTokens = [_LUSD, _3CRV];

        stakerImplementation = new ConvexLUSDv3CRVStaker();
        staker = ConvexLUSDv3CRVStaker(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.initialize.selector, coreBorrow)
            )
        );

        swapper = new MockCurveLevSwapperLUSDv3CRV(
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
        _3CRV.approve(address(swapper), type(uint256).max);
        _LUSD.approve(address(swapper), type(uint256).max);
        vm.stopPrank();
    }

    function testInitialise() public {
        assertEq(staker.name(), "Angle Curve.fi Factory USD Metapool: Liquity Convex Staker");
        assertEq(staker.symbol(), "agstk-cvx-LUSD3CRV-f");
        assertEq(staker.decimals(), 18);
    }

    function testLeverageNoUnderlyingTokensDeposited(uint256 amount) public {
        amount = bound(amount, 1, 10**27);
        _depositDirect(amount);

        assertEq(staker.balanceOf(_alice), amount);
        assertEq(tokenHolder.balanceOf(address(staker)), amount);
        assertEq(staker.balanceOf(_alice), staker.totalSupply());
        _assertCommonLeverage();
    }

    function testLeverageSuccess(uint256[2] memory amounts) public {
        uint256 minAmountOut = _depositSwapAndAddLiquidity(amounts);

        assertGe(staker.balanceOf(_alice), minAmountOut);
        assertGe(tokenHolder.balanceOf(address(staker)), minAmountOut);
        assertEq(staker.balanceOf(_alice), staker.totalSupply());
        _assertCommonLeverage();
    }

    function testNoDepositDeleverageBalance(uint256 amount) public {
        amount = bound(amount, 1, 10**24);
        _depositDirect(amount);
        uint256[2] memory minAmounts = _deleverageBalance();

        assertGe(_LUSD.balanceOf(_alice), minAmounts[0]);
        assertGe(_3CRV.balanceOf(_alice), minAmounts[1]);
        _assertCommonDeleverage();
    }

    function testDeleverageOneCoinToken(
        uint256[2] memory amounts,
        uint256 swapAmount,
        uint256 coinIndex,
        int128 coinSwap
    ) public {
        coinIndex = bound(coinIndex, 0, 1);
        _depositSwapAndAddLiquidity(amounts);
        _swapToImbalance(coinSwap, coinSwap, swapAmount);

        IERC20 outToken = listTokens[coinIndex];
        uint256 minOneCoin = _deleverageOneCoin(int128(uint128(coinIndex)), outToken);

        for (uint256 i; i < listTokens.length; i++) {
            if (i == coinIndex) assertGe(listTokens[i].balanceOf(_alice), minOneCoin);
            else assertEq(listTokens[i].balanceOf(_alice), 0);
        }
        _assertCommonDeleverage();
    }

    function testDeleverageBalance(
        uint256[2] memory amounts,
        uint256 swapAmount,
        int128 coinSwap
    ) public {
        _depositSwapAndAddLiquidity(amounts);
        _swapToImbalance(coinSwap, coinSwap, swapAmount);

        uint256[2] memory minAmounts = _deleverageBalance();

        assertGe(_LUSD.balanceOf(_alice), minAmounts[0]);
        assertGe(_3CRV.balanceOf(_alice), minAmounts[1]);
        _assertCommonDeleverage();
    }

    // function testDeleverageImbalance(
    //     uint256[4] memory amounts,
    //     uint256 swapAmount,
    //     int128 coinSwap,
    //     uint256 proportionWithdrawToken
    // ) public {
    //     proportionWithdrawToken = bound(proportionWithdrawToken, 5 * 10**8, 5 * 10**8);
    //     _depositSwapAndAddLiquidity(amounts);
    //     _swapToImbalance(coinSwap, coinSwap, swapAmount);

    //     (uint256[2] memory amountOut, uint256 keptLPToken) = _deleverageImbalance(proportionWithdrawToken);
    //     if (amountOut[0] < 10 wei && amountOut[1] < 10 wei) return;

    //     // Aave balances have rounding issues as they are corrected by an index
    //     assertEq(_LUSD.balanceOf(_alice), amountOut[0]);
    //     assertEq(_3CRV.balanceOf(_alice), amountOut[1]);
    //     assertEq(_DAI.balanceOf(_bob), 0);
    //     assertEq(_USDC.balanceOf(_bob), 0);
    //     assertEq(_USDT.balanceOf(_bob), 0);
    //     assertLe(staker.balanceOf(_bob), keptLPToken);
    //     assertLe(staker.totalSupply(), keptLPToken);
    //     assertLe(asset.balanceOf(address(staker)), keptLPToken);
    //     _assertCommonLeverage();
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

    function _depositSwapAndAddLiquidity(uint256[2] memory amounts) internal returns (uint256 minAmountOut) {
        // LUSD - 3CRV
        amounts[0] = bound(amounts[0], 1, 10**(18 + 6));
        amounts[1] = bound(amounts[1], 1, 10**(18 + 6));

        deal(address(_LUSD), address(_alice), amounts[0]);
        deal(address(_3CRV), address(_alice), amounts[1]);

        vm.startPrank(_alice);
        // intermediary variables
        bytes[] memory oneInchData;

        oneInchData = new bytes[](0);
        {
            minAmountOut =
                (IMetaPool2(address(_METAPOOL)).calc_token_amount([amounts[0], amounts[1]], true) * SLIPPAGE_BPS) /
                _BPS;
        }

        bytes memory addData = abi.encode(true);
        bytes memory swapData = abi.encode(oneInchData, addData);
        bytes memory leverageData = abi.encode(true, _alice, swapData);
        bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

        // we first need to send the tokens before hand, you should always use the swapper
        // in another tx to not losse your funds by front running
        _LUSD.safeTransfer(address(swapper), amounts[0]);
        _3CRV.safeTransfer(address(swapper), amounts[1]);
        swapper.swap(IERC20(address(_3CRV)), IERC20(address(staker)), _alice, 0, amounts[1], data);

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
            bytes memory removeBPData;
            bytes memory removeData = abi.encode(
                CurveRemovalType.oneCoin,
                abi.encode(coinIndex, minOneCoin, removeBPData)
            );
            bytes memory swapData = abi.encode(amount, amount, sweepTokens, oneInchData, removeData);
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
            bytes memory removeBPData;
            bytes memory removeData = abi.encode(CurveRemovalType.balance, abi.encode(minAmounts, removeBPData));
            bytes memory swapData = abi.encode(amount, amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), minAmounts[1], SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(staker)), IERC20(address(_3CRV)), _alice, 0, amount, data);

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
                // add a slippage on the returned amount
                amountOuts = [
                    ((minAmounts[0] + minAmounts[1]) * (10**9 - proportionWithdrawToken) * SLIPPAGE_BPS) /
                        (10**9 * _BPS),
                    ((minAmounts[0] + minAmounts[1]) * proportionWithdrawToken * SLIPPAGE_BPS) / (10**9 * _BPS)
                ];
                // if we try to withdraw more than the curve balances -> rebalance
                uint256 curveBalanceLUSD = _METAPOOL.balances(0);
                uint256 curveBalance3CRV = _METAPOOL.balances(1);
                if (curveBalanceLUSD < amountOuts[0]) {
                    amountOuts[0] = curveBalanceLUSD**99 / 100;
                } else if (curveBalance3CRV < amountOuts[1]) {
                    amountOuts[1] = curveBalance3CRV**99 / 100;
                }
                if (amountOuts[0] < 10 wei && amountOuts[1] < 10 wei) return (amountOuts, 0);
            }
            maxBurnAmount = IMetaPool2(address(_METAPOOL)).calc_token_amount(amountOuts, false);
            // // Again there can be rounding issues on Aave because of the index value
            // uint256 minAmountOut = amountOuts[1] > 5 wei ? amountOuts[1] - 5 wei : 0;

            bytes[] memory oneInchData = new bytes[](0);
            IERC20[] memory sweepTokens = new IERC20[](1);
            sweepTokens[0] = _LUSD;
            bytes memory removeBPData;
            bytes memory removeData = abi.encode(
                CurveRemovalType.imbalance,
                abi.encode(_bob, amountOuts, removeBPData)
            );
            bytes memory swapData = abi.encode(amount, amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), amountOuts[1], SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(staker)), IERC20(address(_3CRV)), _alice, 0, amount, data);

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
        if (coinSwapFrom == 1) {
            swapAmount = bound(swapAmount, 10**18, 10**24);
            deal(address(_3CRV), address(_dylan), swapAmount);
            _3CRV.approve(address(_METAPOOL), type(uint256).max);
        } else {
            swapAmount = bound(swapAmount, 10**18, 10**(18 + 6));
            deal(address(_LUSD), address(_dylan), swapAmount);
            _LUSD.approve(address(_METAPOOL), type(uint256).max);
        }
        _METAPOOL.exchange(coinSwapFrom, int128(1 - uint128(coinSwapFrom)), swapAmount, 0);

        vm.stopPrank();
    }

    function _assertCommonLeverage() internal {
        assertEq(staker.balanceOf(address(swapper)), 0);
        assertEq(asset.balanceOf(address(_alice)), 0);
        assertEq(asset.balanceOf(address(swapper)), 0);
        assertEq(tokenHolder.balanceOf(address(staker)), staker.totalSupply());
        assertEq(_LUSD.balanceOf(address(swapper)), 0);
        assertEq(_3CRV.balanceOf(address(swapper)), 0);
        assertEq(_LUSD.balanceOf(address(staker)), 0);
        assertEq(_3CRV.balanceOf(address(staker)), 0);
    }

    function _assertCommonDeleverage() internal {
        _assertCommonLeverage();
        assertEq(staker.balanceOf(_alice), 0);
        assertEq(tokenHolder.balanceOf(address(staker)), 0);
        assertEq(staker.totalSupply(), 0);
    }
}
