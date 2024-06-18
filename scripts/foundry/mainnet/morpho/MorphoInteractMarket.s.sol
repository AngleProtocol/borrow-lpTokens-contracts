// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StdCheats, StdAssertions } from "forge-std/Test.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { SwapType, BaseLevSwapper, PendleLevSwapperMorpho, Swapper } from "borrow-staked/swapper/LevSwapper/morpho/implementations/PendleLevSwapperMorphoWeETH.sol";
import { MarketParams } from "morpho-blue/libraries/MarketParamsLib.sol";
import { IIrm } from "morpho-blue/interfaces/IIRM.sol";
import { IMorpho, Position, Market } from "morpho-blue/interfaces/IMorpho.sol";
import { IOracle as IMorphoOracle } from "morpho-blue/interfaces/IOracle.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { BaseFeedPTPendle } from "borrow/oracle/BaseFeedPTPendle.sol";
import { IAccessControlManager } from "borrow/interfaces/IAccessControlManager.sol";
import "borrow-staked/interfaces/external/morpho/IMorphoChainlinkOracleV2Factory.sol";
import { MorphoBalancesLib } from "morpho-blue/libraries/periphery/MorphoBalancesLib.sol";
import { MarketParamsLib } from "morpho-blue/libraries/MarketParamsLib.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";
import "../MainnetConstants.s.sol";
import { MathLib, WAD } from "morpho-blue/libraries/MathLib.sol";
import { SharesMathLib } from "morpho-blue/libraries/SharesMathLib.sol";
import { UtilsLib } from "morpho-blue/libraries/UtilsLib.sol";

struct MarketConfig {
    /// @notice The maximum amount of assets that can be allocated to the market.
    uint184 cap;
    /// @notice Whether the market is in the withdraw queue.
    bool enabled;
    /// @notice The timestamp at which the market can be instantly removed from the withdraw queue.
    uint64 removableAt;
}

interface MetaMorphoVault {
    function submitCap(MarketParams memory marketParams, uint256 newSupplyCap) external;

    function acceptCap(MarketParams memory marketParams) external;

    function updateWithdrawQueue(uint256[] calldata indexes) external;

    function submitMarketRemoval(MarketParams memory marketParams) external;

    function config(bytes32 id) external returns (MarketConfig memory);
}

struct MarketReduced {
    uint256 totalSupplyAssets;
    uint256 totalSupplyShares;
    uint256 totalBorrowAssets;
    uint256 totalBorrowShares;
}

contract MorphoInteractMarket is Script, MainnetConstants, StdCheats, StdAssertions {
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint128;
    using MathLib for uint256;

    // depend on the market
    uint256 constant BASE_DEPOSIT_AMOUNT = BASE_DEPOSIT_ETH_AMOUNT;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address gauntletCurator = 0xC684c6587712e5E7BDf9fD64415F23Bd2b05fAec;
        address largeBorrower = 0xaFeb95DEF3B2A3D532D74DaBd51E62048d6c07A4;
        // vm.startBroadcast(deployerPrivateKey);
        vm.startBroadcast(GUARDIAN);
        // vm.startBroadcast(largeBorrower);
        // IERC20(USDA).approve(MORPHO_BLUE, 1 ether);

        MarketParams memory params;
        bytes memory emptyData;
        bytes32 salt;
        params.irm = IRM_MODEL;
        params.loanToken = USDA;

        // {
        //     address oracle = 0x1f083a4c51E6cAa627A8Cbe7452bF3D6eb815F57;
        //     params.collateralToken = RE7USDT;
        //     params.lltv = LLTV_91;
        //     params.oracle = oracle;

        //     _getBalances(params, deployer);
        //     _repay(params, 0.11 ether, deployer);
        //     _getBalances(params, deployer);

        //     // IMorpho(MORPHO_BLUE).supply(params, 35 ether, 0, deployer, emptyData);
        //     // IMorpho(MORPHO_BLUE).withdraw(params, 999 ether, 0, deployer, deployer);
        //     // IERC20(params.collateralToken).approve(MORPHO_BLUE, BASE_DEPOSIT_AMOUNT);
        //     // IMorpho(MORPHO_BLUE).supplyCollateral(params, BASE_DEPOSIT_AMOUNT, deployer, emptyData);
        //     // IMorpho(MORPHO_BLUE).borrow(params, 20 ether, 0, deployer, deployer);
        //     // IMorpho(MORPHO_BLUE).repay(params, 50 ether, 0, deployer, emptyData);
        // }

        // {
        //     params.collateralToken = EZETH;
        //     params.lltv = LLTV_77;
        //     params.oracle = 0xd5116061F4a1FFac23E9c6c9f6B4AF28b9AF7676;
        //     _getBalances(params, 0xB4F78a5adC242f67dFe3391cEa55Dc882BcaAd7C);
        // }

        // {
        //     address oracle = 0x76052A2A28fDCB8124f4686C63C68355b142de3B;
        //     params.collateralToken = RE7ETH;
        //     params.lltv = LLTV_86;
        //     params.oracle = oracle;

        //     _getBalances(params, deployer);
        //     _repay(params, 0.11 ether, deployer);
        //     _getBalances(params, deployer);
        // }

        // {
        //     address oracle = 0x3B8c4A340336941524DE276FF730b3Be71157B55;
        //     params.collateralToken = GTUSDCPRIME;
        //     params.lltv = LLTV_86;
        //     params.oracle = oracle;

        //     _getBalances(params, deployer);
        //     _repay(params, 0.11 ether, deployer);
        //     _getBalances(params, deployer);
        // }

        // {
        //     address oracle = 0xe4CCAA1849e9058f77f555C0FCcA4925Efd37d8E;
        //     params.collateralToken = GTETHPRIME;
        //     params.lltv = LLTV_77;
        //     params.oracle = oracle;

        //     _getBalances(params, deployer);
        //     _repay(params, 0.11 ether, deployer);
        //     _getBalances(params, deployer);
        // }

        // {
        //     address oracle = 0x5441731eED05A8208e795086a5dF41416DD34104;
        //     params.collateralToken = PTWeETH;
        //     params.lltv = LLTV_86;
        //     params.oracle = oracle;

        //     _getBalances(params, 0x36dfe6EDdef7d32497e15cdF826D6Cf4ee9293aF);

        //     uint256 seizedAssets = 4838661537579587905;
        //     // uint256 liquidationIncentiveFactor = 1043841336116910226;
        //     uint256 collateralPrice = 3033381360515936091937613849700000000000;
        //     uint256 ORACLE_PRICE_SCALE = 1000000000000000000000000000000000000;
        //     uint256 LIQUIDATION_CURSOR = 0.3e18;
        //     uint256 MAX_LIQUIDATION_INCENTIVE_FACTOR = 1.15e18;
        //     uint256 borrowShares = 13826871403438882335074967310;

        //     MarketReduced memory market;
        //     (
        //         market.totalSupplyAssets,
        //         market.totalSupplyShares,
        //         market.totalBorrowAssets,
        //         market.totalBorrowShares
        //     ) = IMorpho(MORPHO_BLUE).expectedMarketBalances(params);

        //     // The liquidation incentive factor is min(maxLiquidationIncentiveFactor, 1/(1 - cursor*(1 - lltv))).
        //     uint256 liquidationIncentiveFactor = UtilsLib.min(
        //         MAX_LIQUIDATION_INCENTIVE_FACTOR,
        //         WAD.wDivDown(WAD - LIQUIDATION_CURSOR.wMulDown(WAD - params.lltv))
        //     );

        //     console.log("liquidationIncentiveFactor: ", liquidationIncentiveFactor);

        //     uint256 seizedAssetsQuoted = seizedAssets.mulDivUp(collateralPrice, ORACLE_PRICE_SCALE);

        //     console.log("seizedAssetsQuoted: ", seizedAssetsQuoted);

        //     uint256 repaidShares = seizedAssetsQuoted.wDivUp(liquidationIncentiveFactor).toSharesUp(
        //         market.totalBorrowAssets,
        //         market.totalBorrowShares
        //     );

        //     console.log("repaidShares: ", repaidShares);

        //     uint256 repaidAssets = repaidShares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
        //     console.log("repaidAssets: ", repaidAssets);

        //     console.log("totalBorrowShares: ", market.totalBorrowShares);
        //     console.log("totalBorrowAssets: ", market.totalBorrowAssets);

        // position[id][borrower].borrowShares -= repaidShares.toUint128();
        // market[id].totalBorrowShares -= repaidShares.toUint128();
        // market[id].totalBorrowAssets = UtilsLib
        //     .zeroFloorSub(market[id].totalBorrowAssets, repaidAssets)
        //     .toUint128();

        //     // position[id][borrower].collateral -= seizedAssets.toUint128();

        //     // _repay(params, 50 ether, deployer);
        // }

        // {
        //     params.collateralToken = PTUSDe;
        //     params.lltv = LLTV_86;
        //     params.oracle = 0x81B379f99CeE4Ee08f8CBC476e80e756D3b172cc;
        //     _getBalances(params, deployer);
        //     _repay(params, 50 ether, deployer);
        // }

        // // Check variables
        // // PT-USDe
        // {
        //     params.collateralToken = PTUSDe;
        //     params.lltv = LLTV_86;
        //     params.oracle = 0x81B379f99CeE4Ee08f8CBC476e80e756D3b172cc;
        //     _getBalances(params, deployer);
        //     _withdrawCollateral(params, 8.5 ether, deployer);
        // }

        // // gtUSDCPrime
        // {
        //     params.collateralToken = GTUSDCPRIME;
        //     params.lltv = LLTV_86;
        //     params.oracle = 0x3B8c4A340336941524DE276FF730b3Be71157B55;
        //     _getBalances(params, deployer);
        //     _withdrawCollateral(params, 9.5 ether, deployer);
        // }

        // PT markets
        {
            IMorphoOracle oracle = IMorphoOracle(0x5441731eED05A8208e795086a5dF41416DD34104);
            address priceFeed = 0xC9dfD5c18F12a3BA6293001700810602efe0c45B;
            // To force liquidation update some storage
            (, int256 pricePT, , , ) = BaseFeedPTPendle(priceFeed).latestRoundData();
            console.log(oracle.price());
            // PT manipulation
            BaseFeedPTPendle(priceFeed).setMaxImpliedRate(1000 ether);
            (, pricePT, , , ) = BaseFeedPTPendle(priceFeed).latestRoundData();
            console.log(oracle.price());
        }
        // // ERC4626
        // // Rehypothecated morpho vaults
        // {
        //     IERC4626(GTUSDCPRIME).convertToAssets(1 ether);
        //     params.loanToken = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        //     params.collateralToken = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
        //     params.oracle = 0x48F7E36EB6B826B2dF4B2E630B62Cd25e89E40e2;
        //     params.irm = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
        //     params.lltv = 860000000000000000;
        //     // MetaMorphoVault(GTUSDCPRIME).submitCap(params, 0 ether);
        //     // MetaMorphoVault(GTUSDCPRIME).submitMarketRemoval(params);
        //     MarketConfig memory config = MetaMorphoVault(GTUSDCPRIME).config(
        //         bytes32(0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc)
        //     );
        //     uint256[] memory newWithdrawQueue = new uint256[](1);
        //     newWithdrawQueue[0] = 0;
        //     // newWithdrawQueue[1] = 1;
        //     MetaMorphoVault(GTUSDCPRIME).updateWithdrawQueue(newWithdrawQueue);
        //     IERC4626(GTUSDCPRIME).convertToAssets(1 ether);
        // }

        vm.stopBroadcast();
    }

    function _repay(MarketParams memory params, uint256 amount, address borrower) internal {
        bytes memory emptyData;
        IMorpho(MORPHO_BLUE).repay(params, amount, 0, borrower, emptyData);
    }

    function _withdrawCollateral(MarketParams memory params, uint256 amount, address borrower) internal {
        bytes memory emptyData;
        IMorpho(MORPHO_BLUE).withdrawCollateral(params, amount, borrower, borrower);
    }

    function _getBalances(MarketParams memory params, address account) internal view {
        Position memory position = IMorpho(MORPHO_BLUE).position(params.id(), account);
        console.log("collateral: ", position.collateral);
        console.log("borrow shares: ", position.borrowShares);
        uint256 balance = IMorpho(MORPHO_BLUE).expectedBorrowAssets(params, account);
        console.log("borrow: ", balance);
        uint256 totalBorrow = IMorpho(MORPHO_BLUE).expectedTotalBorrowAssets(params);
        console.log("totalBorrow: ", totalBorrow);
        uint256 borrowRate = IIrm(params.irm).borrowRateView(params, IMorpho(MORPHO_BLUE).market(params.id()));
        console.log("borrowRate: ", borrowRate * 365 * 24 * 60 * 60);
    }
}

// {
//   "AboveMaxTimelock()": "46fedb57",
//   "AddressEmptyCode(address)": "9996b315",
//   "AddressInsufficientBalance(address)": "cd786059",
//   "AllCapsReached()": "ded0652d",
//   "AlreadyPending()": "49b204ce",
//   "AlreadySet()": "a741a045",
//   "BelowMinTimelock()": "342b27be",
//   "DuplicateMarket(bytes32)": "92a726c3",
//   "ECDSAInvalidSignature()": "f645eedf",
//   "ECDSAInvalidSignatureLength(uint256)": "fce698f7",
//   "ECDSAInvalidSignatureS(bytes32)": "d78bce0c",
//   "ERC20InsufficientAllowance(address,uint256,uint256)": "fb8f41b2",
//   "ERC20InsufficientBalance(address,uint256,uint256)": "e450d38c",
//   "ERC20InvalidApprover(address)": "e602df05",
//   "ERC20InvalidReceiver(address)": "ec442f05",
//   "ERC20InvalidSender(address)": "96c6fd1e",
//   "ERC20InvalidSpender(address)": "94280d62",
//   "ERC2612ExpiredSignature(uint256)": "62791302",
//   "ERC2612InvalidSigner(address,address)": "4b800e46",
//   "ERC4626ExceededMaxDeposit(address,uint256,uint256)": "79012fb2",
//   "ERC4626ExceededMaxMint(address,uint256,uint256)": "284ff667",
//   "ERC4626ExceededMaxRedeem(address,uint256,uint256)": "b94abeec",
//   "ERC4626ExceededMaxWithdraw(address,uint256,uint256)": "fe9cceec",
//   "FailedInnerCall()": "1425ea42",
//   "InconsistentAsset(bytes32)": "cf2ff49c",
//   "InconsistentReallocation()": "9e36b890",
//   "InvalidAccountNonce(address,uint256)": "752d88c0",
//   "InvalidMarketRemovalNonZeroCap(bytes32)": "803b07b2",
//   "InvalidMarketRemovalNonZeroSupply(bytes32)": "af8ae287",
//   "InvalidMarketRemovalTimelockNotElapsed(bytes32)": "b3544664",
//   "InvalidShortString()": "b3512b0c",
//   "MarketNotCreated()": "96e13529",
//   "MarketNotEnabled(bytes32)": "6113d8c7",
//   "MathOverflowedMulDiv()": "227bc153",
//   "MaxFeeExceeded()": "f4df6ae5",
//   "MaxQueueLengthExceeded()": "80f2f7ae",
//   "NoPendingValue()": "e5f408a5",
//   "NonZeroCap()": "c48e3172",
//   "NotAllocatorRole()": "f7137c0f",
//   "NotCuratorNorGuardianRole()": "d080fa31",
//   "NotCuratorRole()": "ca899cec",
//   "NotEnoughLiquidity()": "4323a555",
//   "NotGuardianRole()": "f9f2fc9a",
//   "OwnableInvalidOwner(address)": "1e4fbdf7",
//   "OwnableUnauthorizedAccount(address)": "118cdaa7",
//   "PendingCap(bytes32)": "463af300",
//   "PendingRemoval()": "4bec0146",
//   "SafeCastOverflowedUintDowncast(uint8,uint256)": "6dfcc650",
//   "SafeERC20FailedOperation(address)": "5274afe7",
//   "StringTooLong(string)": "305a27a9",
//   "SupplyCapExceeded(bytes32)": "5e25afa5",
//   "TimelockNotElapsed()": "6677a596",
//   "UnauthorizedMarket(bytes32)": "67f0a250",
//   "ZeroAddress()": "d92e233d",
//   "ZeroFeeRecipient()": "cff9f194"
// }
