// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

contract BaseConstants {
    address public constant ONE_INCH = 0x111111125421cA6dc452d289314280a0f8842A65;
    address public constant MORPHO_BLUE = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address public constant ANGLE_ROUTER = 0x423Cf4cD872F912D278DF2F54Ae58Aa8073cb38c;
    address public constant UNI_V3_ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481;
    address public constant PYTH_ROUTER = 0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a;

    uint256 public constant BASE_TOKENS = 10 ** 18;
    uint64 public constant BASE_PARAMS = 10 ** 9;

    address constant ezETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address constant weETH = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
    address constant wstETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
    address constant cbETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;

    // Chainlink
    address constant ETH_USD_ORACLE = address(0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70);
    // Chainlink
    address constant EZETH_ETH_ORACLE = address(0x960BDD1dFD20d7c98fa482D793C3dedD73A113a3);
    // Chainlink
    address constant WEETH_ETH_ORACLE = address(0xFC1415403EbB0c693f9a7844b92aD2Ff24775C65);
    bytes32 constant WEETH_USD_PYTH_ID = 0x9ee4e7c60b940440a261eb54b6d8149c23b580ed7da3139f7f08f4ea29dad395;
    // Chainlink
    address constant WSTETH_ETH_ORACLE = address(0xa669E5272E60f78299F4824495cE01a3923f4380);
    bytes32 constant WSTETH_USD_PYTH_ID = 0x6df640f3b8963d8f8358f791f352b8364513f6ab1cca5ed3f1f7b5448980e784;
    // Chainlink
    address constant CBETH_ETH_ORACLE = 0x806b4Ac04501c29769051e42783cF04dCE41440b;
    bytes32 constant CBETH_USD_PYTH_ID = 0x15ecddd26d49e1a8f1de9376ebebc03916ede873447c1255d2d5891b92ce5717;

    address constant MORPHO_ORACLE_FACTORY = 0x2DC205F24BCb6B311E5cdf0745B0741648Aebd3d;
    address constant IRM_MODEL = 0x46415998764C29aB2a25CbeA6254146D50D22687;

    uint256 constant LLTV_91 = 0.915 ether;
    uint256 constant LLTV_86 = 0.86 ether;
    uint256 constant LLTV_77 = 0.77 ether;
    uint256 constant LLTV_62 = 0.625 ether;

    uint32 constant _TWAP_DURATION = 1 hours;
    uint32 constant _STALE_PERIOD = 24 hours;
    uint256 constant _MAX_IMPLIED_RATE = 0.5 ether;

    uint256 constant BASE_DEPOSIT_ETH_AMOUNT = 0.002 ether;
    uint256 constant BASE_DEPOSIT_USD_AMOUNT = 1 ether;
}
