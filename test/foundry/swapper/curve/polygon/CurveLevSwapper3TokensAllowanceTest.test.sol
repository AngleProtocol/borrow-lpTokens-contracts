// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../../BaseTest.test.sol";
import { ILendingPool } from "../../../../../contracts/interfaces/external/aave/ILendingPool.sol";
import "../../../../../contracts/interfaces/IBorrowStaker.sol";
import "../../../../../contracts/interfaces/ICoreBorrow.sol";
import "../../../../../contracts/interfaces/external/curve/IMetaPool3.sol";
import { MockCurveLevSwapperAaveBP, Swapper, IUniswapV3Router, IAngleRouterSidechain } from "../../../../../contracts/swapper/LevSwapper/curve/implementations/polygon/polygonTest/MockCurveLevSwapperAaveBP.sol";

// @dev Testing on Polygon
contract CurveLevSwapper3TokensAllowanceTest is BaseTest {
    using stdStorage for StdStorage;

    address internal constant _ONE_INCH = 0x1111111254fb6c44bAC0beD2854e76F90643097d;
    IUniswapV3Router internal constant _UNI_V3_ROUTER = IUniswapV3Router(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IAngleRouterSidechain internal constant _ANGLE_ROUTER =
        IAngleRouterSidechain(address(uint160(uint256(keccak256(abi.encodePacked("_fakeAngleRouter"))))));
    IERC20 public asset = IERC20(0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171);
    IERC20 internal constant _USDC = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 internal constant _USDT = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    IERC20 internal constant _DAI = IERC20(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    IERC20 internal constant _amUSDC = IERC20(0x1a13F4Ca1d028320A707D99520AbFefca3998b7F);
    IERC20 internal constant _amUSDT = IERC20(0x60D55F02A771d515e077c9C2403a1ef324885CeC);
    IERC20 internal constant _amDAI = IERC20(0x27F8D03b3a2196956ED754baDc28D73be8830A6e);
    uint256 internal constant _DECIMAL_NORM_USDC = 10**12;
    uint256 internal constant _DECIMAL_NORM_USDT = 10**12;

    IMetaPool3 internal constant _METAPOOL = IMetaPool3(0x445FE580eF8d70FF569aB36e80c647af338db351);
    ILendingPool internal constant _AAVE_LENDING_POOL = ILendingPool(0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf);
    IBorrowStaker internal constant _STAKER = IBorrowStaker(0xe1Bc17f85d54a81068FC510d5A94E95800D342d9);

    MockCurveLevSwapperAaveBP public swapper;

    function setUp() public override {
        super.setUp();

        _polygon = vm.createFork(vm.envString("ETH_NODE_URI_POLYGON"), 36004278);
        vm.selectFork(_polygon);

        // reset coreBorrow because the `makePersistent()` doens't work on my end
        coreBorrow = new MockCoreBorrow();
        coreBorrow.toggleGuardian(_GUARDIAN);
        coreBorrow.toggleGovernor(_GOVERNOR);

        swapper = new MockCurveLevSwapperAaveBP(coreBorrow, _UNI_V3_ROUTER, _ONE_INCH, _ANGLE_ROUTER);
    }

    function testAllowances() public {
        assertEq(_amUSDC.allowance(address(swapper), address(_METAPOOL)), type(uint256).max);
        assertEq(_amUSDT.allowance(address(swapper), address(_METAPOOL)), type(uint256).max);
        assertEq(_amDAI.allowance(address(swapper), address(_METAPOOL)), type(uint256).max);
        assertEq(asset.allowance(address(swapper), address(_STAKER)), type(uint256).max);
    }
}
