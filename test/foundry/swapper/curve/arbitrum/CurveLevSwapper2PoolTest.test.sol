// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../../BaseTest.test.sol";
import "../../../../../contracts/interfaces/IBorrowStaker.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "../../../../../contracts/interfaces/external/curve/IMetaPool2.sol";
import "borrow/interfaces/coreModule/IStableMaster.sol";
import "borrow/interfaces/coreModule/IPoolManager.sol";
import "../../../../../contracts/mock/MockTokenPermit.sol";
import { CurveRemovalType, SwapType, BaseLevSwapper, MockCurveLevSwapper2Pool, Swapper, IUniswapV3Router, IAngleRouterSidechain } from "../../../../../contracts/mock/implementations/swapper/arbitrum/MockCurveLevSwapper2Pool.sol";
import { MockBorrowStaker } from "../../../../../contracts/mock/MockBorrowStaker.sol";

contract CurveLevSwapper2PoolTest is BaseTest {
    using stdStorage for StdStorage;
    using SafeERC20 for IERC20;

    address internal constant _ONE_INCH = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    IUniswapV3Router internal constant _UNI_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAngleRouterSidechain internal constant _ANGLE_ROUTER =
        IAngleRouterSidechain(address(uint160(uint256(keccak256(abi.encodePacked("_fakeAngleRouter"))))));
    IERC20 public asset = IERC20(0x7f90122BF0700F9E7e1F688fe926940E8839F353);
    IERC20 internal constant _USDC = IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 internal constant _USDT = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    uint256 internal constant _DECIMAL_NORM_USDC = 10**12;
    uint256 internal constant _DECIMAL_NORM_USDT = 10**12;
    IERC20[2] internal listTokens;

    IMetaPool2 internal constant _METAPOOL = IMetaPool2(0x7f90122BF0700F9E7e1F688fe926940E8839F353);

    uint256 internal constant _BPS = 10000;
    MockCurveLevSwapper2Pool public swapper;
    MockBorrowStaker public stakerImplementation;
    MockBorrowStaker public staker;
    IERC20 public tokenHolder;
    uint256 public SLIPPAGE_BPS = 9900;

    function setUp() public virtual override {
        super.setUp();

        _arbitrum = vm.createFork(vm.envString("ETH_NODE_URI_ARBITRUM"), 58545851);
        vm.selectFork(_arbitrum);

        listTokens = [_USDC, _USDT];
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

        swapper = new MockCurveLevSwapper2Pool(
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
        vm.stopPrank();
    }

    function testInitialise() public virtual {
        assertEq(staker.name(), "Angle Curve.fi USDC/USDT Mock Staker");
        assertEq(staker.symbol(), "agstk-mock-2CRV");
        assertEq(staker.decimals(), 18);
    }

    function testLeverageNoUnderlyingTokensDeposited(uint256 amount) public {
        amount = bound(amount, 1, 10**27);

        _depositDirect(amount);

        assertEq(staker.balanceOf(_alice), amount);
        assertEq(tokenHolder.balanceOf(address(staker)), amount);
        assertEq(staker.balanceOf(_alice), staker.totalSupply());
        assertEq(_USDC.balanceOf(_alice), 0);
        assertEq(_USDT.balanceOf(_alice), 0);
        _assertCommonLeverage();
    }

    function testLeverageSuccess(uint256[2] memory amounts) public {
        uint256 minAmountOut = _depositSwapAndAddLiquidity(amounts);

        assertGt(staker.balanceOf(_alice), minAmountOut);
        assertGt(tokenHolder.balanceOf(address(staker)), minAmountOut);
        assertEq(staker.balanceOf(_alice), staker.totalSupply());
        assertEq(_USDC.balanceOf(_alice), 0);
        assertEq(_USDT.balanceOf(_alice), 0);
        _assertCommonLeverage();
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
        int128 coinSwapFrom,
        int128 coinSwapTo
    ) public {
        _depositSwapAndAddLiquidity(amounts);
        _swapToImbalance(coinSwapFrom, coinSwapTo, swapAmount);
        uint256[2] memory minAmounts = _deleverageBalance();

        assertGe(_USDC.balanceOf(_alice), minAmounts[0]);
        assertGe(_USDT.balanceOf(_alice), minAmounts[1]);
        _assertCommonDeleverage();
    }

    function testDeleverageImbalance(
        uint256[2] memory amounts,
        uint256 swapAmount,
        int128 coinSwapFrom,
        int128 coinSwapTo,
        uint256 proportionWithdrawToken
    ) public {
        _depositSwapAndAddLiquidity(amounts);
        _swapToImbalance(coinSwapFrom, coinSwapTo, swapAmount);

        proportionWithdrawToken = bound(proportionWithdrawToken, 0, 10**9);

        (uint256[2] memory amountOut, uint256 keptLPToken) = _deleverageImbalance(proportionWithdrawToken);
        if (amountOut[0] < 10 wei && amountOut[1] < 10 wei) return;

        assertGe(_USDC.balanceOf(_alice), amountOut[0]);
        assertGe(_USDT.balanceOf(_alice), amountOut[1]);
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

    function _depositSwapAndAddLiquidity(uint256[2] memory amounts) internal returns (uint256 minAmountOut) {
        // USDC - USDT
        amounts[0] = bound(amounts[0], 1, 10**11);
        amounts[1] = bound(amounts[1], 1, 10**11);

        deal(address(_USDC), address(_alice), amounts[0]);
        deal(address(_USDT), address(_alice), amounts[1]);

        vm.startPrank(_alice);

        // intermediary variables
        bytes[] memory oneInchData;
        oneInchData = new bytes[](0);

        minAmountOut =
            (IMetaPool2(address(_METAPOOL)).calc_token_amount([amounts[0], amounts[1]], true) * SLIPPAGE_BPS) /
            _BPS;

        bytes memory addData;
        bytes memory swapData = abi.encode(oneInchData, addData);
        bytes memory leverageData = abi.encode(true, _alice, swapData);
        bytes memory data = abi.encode(address(0), 0, SwapType.Leverage, leverageData);

        // we first need to send the tokens before hand, you should always use the swapper
        // in another tx to not loose your funds via front running
        _USDC.transfer(address(swapper), amounts[0]);
        _USDT.safeTransfer(address(swapper), amounts[1]);
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
            sweepTokens[0] = _USDC;
            minAmounts = [
                (_METAPOOL.balances(0) * amount * SLIPPAGE_BPS) / (_BPS * asset.totalSupply()),
                (_METAPOOL.balances(1) * amount * SLIPPAGE_BPS) / (_BPS * asset.totalSupply())
            ];
            bytes memory removeData = abi.encode(CurveRemovalType.balance, abi.encode(minAmounts));
            bytes memory swapData = abi.encode(amount, amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), minAmounts[1], SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(staker)), IERC20(address(_USDT)), _alice, 0, amount, data);

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
                    ((minAmounts[0] + minAmounts[1]) * (10**9 - proportionWithdrawToken) * SLIPPAGE_BPS) /
                        (10**9 * _BPS),
                    ((minAmounts[0] + minAmounts[1]) * proportionWithdrawToken * SLIPPAGE_BPS) / (10**9 * _BPS)
                ];
                // if we try to withdraw more than the curve balances -> rebalance
                uint256 curveBalanceUSDC = _METAPOOL.balances(0);
                uint256 curveBalanceUSDT = _METAPOOL.balances(1);
                if (curveBalanceUSDC < amountOuts[0]) {
                    amountOuts[0] = curveBalanceUSDC**99 / 100;
                } else if (curveBalanceUSDT < amountOuts[1]) {
                    amountOuts[1] = curveBalanceUSDT**99 / 100;
                }
                if (amountOuts[0] < 10 wei && amountOuts[1] < 10 wei) return (amountOuts, 0);
            }
            maxBurnAmount = IMetaPool2(address(_METAPOOL)).calc_token_amount(amountOuts, false);

            bytes[] memory oneInchData = new bytes[](0);
            IERC20[] memory sweepTokens = new IERC20[](1);
            sweepTokens[0] = _USDC;
            bytes memory removeData = abi.encode(CurveRemovalType.imbalance, abi.encode(_bob, amountOuts));
            bytes memory swapData = abi.encode(amount, amount, sweepTokens, oneInchData, removeData);
            bytes memory leverageData = abi.encode(false, _alice, swapData);
            data = abi.encode(address(0), amountOuts[1], SwapType.Leverage, leverageData);
        }
        staker.transfer(address(swapper), amount);
        swapper.swap(IERC20(address(staker)), IERC20(address(_USDT)), _alice, 0, amount, data);

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
        // size of swaps should be small in magnitude otherwise the _SLIPPAGE_BPS won't be enough
        if (coinSwapFrom == 1) {
            swapAmount = bound(swapAmount, 10**6, 10**11);
            deal(address(_USDT), address(_dylan), swapAmount);
            _USDT.safeApprove(address(_METAPOOL), type(uint256).max);
        } else {
            swapAmount = bound(swapAmount, 10**6, 10**11);
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
        assertEq(tokenHolder.balanceOf(address(staker)), staker.totalSupply());
        assertEq(_USDC.balanceOf(address(swapper)), 0);
        assertEq(_USDT.balanceOf(address(swapper)), 0);
        assertEq(_USDT.balanceOf(address(swapper)), 0);
        assertEq(_USDC.balanceOf(address(staker)), 0);
        assertEq(_USDT.balanceOf(address(staker)), 0);
        assertEq(_USDT.balanceOf(address(staker)), 0);
    }

    function _assertCommonDeleverage() internal {
        _assertCommonLeverage();
        assertEq(staker.balanceOf(_alice), 0);
        assertEq(tokenHolder.balanceOf(address(staker)), 0);
        assertEq(staker.totalSupply(), 0);
    }
}
