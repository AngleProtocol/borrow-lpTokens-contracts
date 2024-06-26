// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

contract MainnetConstants {
    address public constant GOVERNOR = 0xdC4e6DFe07EFCa50a197DF15D9200883eF4Eb1c8;
    address public constant GUARDIAN = 0x0C2553e4B9dFA9f83b1A6D3EAB96c4bAaB42d430;
    address public constant PROXY_ADMIN = 0x1D941EF0D3Bba4ad67DBfBCeE5262F4CEE53A32b;
    address public constant PROXY_ADMIN_GUARDIAN = 0xD9F1A8e00b0EEbeDddd9aFEaB55019D55fcec017;
    address public constant CORE_BORROW = 0x5bc6BEf80DA563EBf6Df6D6913513fa9A7ec89BE;

    address public constant ANGLE_ROUTER = 0x4579709627CA36BCe92f51ac975746f431890930;
    address public constant ONE_INCH = 0x111111125421cA6dc452d289314280a0f8842A65;
    address public constant UNI_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;

    // AGEUR Mainnet treasury
    address public constant AGEUR_TREASURY = 0x8667DBEBf68B0BFa6Db54f550f41Be16c4067d60;

    uint256 public constant BASE_TOKENS = 10 ** 18;
    uint64 public constant BASE_PARAMS = 10 ** 9;

    address constant USDA = 0x0000206329b97DB379d5E1Bf586BbDB969C63274;
    address constant EZETH = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address constant PTWeETH = 0xc69Ad9baB1dEE23F4605a82b3354F8E40d1E5966;
    address constant PTWeETHDec24 = 0x6ee2b5E19ECBa773a352E5B21415Dc419A700d1d;
    address constant PTEzETHDec24 = 0xf7906F274c174A52d444175729E3fa98f9bde285;
    address constant PTUSDe = 0xa0021EF8970104c2d008F38D92f115ad56a9B8e1;
    address constant RSETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address constant GTETHPRIME = 0x2371e134e3455e0593363cBF89d3b6cf53740618;
    address constant GTUSDCPRIME = 0xdd0f28e19C1780eb6396170735D45153D261490d;
    address constant RE7ETH = 0x78Fc2c2eD1A4cDb5402365934aE5648aDAd094d0;
    address constant RE7USDT = 0x95EeF579155cd2C5510F312c8fA39208c3Be01a8;

    address constant EZETH_ETH_ORACLE = 0xF4a3e183F59D2599ee3DF213ff78b1B3b1923696;
    address constant RSETH_ETH_ORACLE = 0xA736eAe8805dDeFFba40cAB8c99bCB309dEaBd9B;
    address constant PTWEETH_WEETH_ORACLE = 0xE8b74600CF80e3B38e2B186c981325FF7Ede161B;
    address constant WEETH_USD_ORACLE = 0xdDb6F90fFb4d3257dd666b69178e5B3c5Bf41136;

    address constant CHAINLINK_ETH_USD_ORACLE = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address constant CHAINLINK_USDT_USD_ORACLE = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
    address constant CHAINLINK_USDC_USD_ORACLE = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

    address constant MORPHO_ORACLE_FACTORY = 0x3A7bB36Ee3f3eE32A60e9f2b33c1e5f2E83ad766;
    address constant IRM_MODEL = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    uint256 constant LLTV_91 = 0.915 ether;
    uint256 constant LLTV_86 = 0.86 ether;
    uint256 constant LLTV_77 = 0.77 ether;
    uint256 constant LLTV_62 = 0.625 ether;

    uint32 constant _TWAP_DURATION = 1 hours;
    uint32 constant _STALE_PERIOD = 24 hours;
    uint256 constant _MAX_IMPLIED_RATE = 0.5 ether;

    uint256 constant BASE_DEPOSIT_ETH_AMOUNT = 0.01 ether;
    uint256 constant BASE_DEPOSIT_USD_AMOUNT = 5 ether;
}
