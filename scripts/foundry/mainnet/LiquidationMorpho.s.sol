// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ERC4626LevSwapperMorphoGauntletUSDCPrime } from "borrow-staked/swapper/LevSwapper/morpho/implementations/ERC4626LevSwapperMorphoGauntletUSDCPrime.sol";
import "./MainnetConstants.s.sol";
import { MarketParams } from "morpho-blue/libraries/MarketParamsLib.sol";

contract LiquidationMorpho is Script, MainnetConstants {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("KEEPER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        MarketParams memory params;
        params.collateralToken = GTUSDCPRIME;
        params.lltv = LLTV_86;
        params.irm = IRM_MODEL;
        params.oracle = 0x4D7d8eF974428a7D73C90B0249003D30cf97239E;
        params.loanToken = USDA;
        address borrower = 0xA9DdD91249DFdd450E81E1c56Ab60E1A62651701;
        uint256 seizedAssets = 50000000000000000000;
        bytes
            memory data = hex"000000000000000000000000dd0f28e19c1780eb6396170735d45153d261490d0000000000000000000000000000206329b97db379d5e1bf586bbdb969c63274000000000000000000000000000000000000000000000002b5e3af16b1880000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000005c0000000000000000000000000a9bbbdde822789f123667044443dc7001fb43c01000000000000000000000000000000000000000000000001158e460913df423e0000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000005200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a9bbbdde822789f123667044443dc7001fb43c01000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000004a0000000000000000000000000000000000000000000000002b26b8169c7af0000000000000000000000000000000000000000000000000002b26b8169c7af000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000004600000000000000000000000000000000000000000000000000000000000000001000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000320000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000000000000000008e15d620000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000028807ed2379000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd09000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000206329b97db379d5e1bf586bbdb969c63274000000000000000000000000e37e799d5077682fa0a244d46e5649f71457bd090000000000000000000000004b1b4fec85e265ce8b152fb233512fe4002fdec30000000000000000000000000000000000000000000000000000000002fd7154000000000000000000000000000000000000000000000002b134541e4aae700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000013c00000000000000000000000000000000000000000000000000011e0000f05120222222fd79264bbe280b4986f6fefbc3524d0137a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800043b6a1fe000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000206329b97db379d5e1bf586bbdb969c63274000000000000000000000000111111125421ca6dc452d289314280a0f8842a6500000000000000000000000000000000000000000000000000000000000000000020d6bdbf780000206329b97db379d5e1bf586bbdb969c63274111111125421ca6dc452d289314280a0f8842a6500000000f737be4600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000002fd7154";

        ERC4626LevSwapperMorphoGauntletUSDCPrime(0x4B1b4fEc85e265cE8b152fB233512FE4002fDEC3).liquidate(
            params,
            borrower,
            seizedAssets,
            data
        );

        vm.stopBroadcast();
    }
}
