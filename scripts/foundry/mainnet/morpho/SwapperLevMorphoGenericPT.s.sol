// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { StdCheats, StdAssertions } from "forge-std/Test.sol";
import "utils/src/CommonUtils.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { PendlePTGenericLevSwapper } from "borrow-staked/swapper/LevSwapper/PendlePTGenericLevSwapper.sol";
import "../MainnetConstants.s.sol";
import { IMorpho } from "morpho-blue/interfaces/IMorpho.sol";
import "borrow/interfaces/ICoreBorrow.sol";
import "@openzeppelin/contracts/interfaces/IERC4626.sol";

contract SwapperLevMorphoGenericPT is Script, CommonUtils, MainnetConstants {
    ICoreBorrow coreBorrow;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        coreBorrow = ICoreBorrow(_chainToContract(CHAIN_ETHEREUM, ContractType.CoreBorrow));
        // coreBorrow = new MockCoreBorrow();
        // coreBorrow.toggleGuardian(deployer);

        PendlePTGenericLevSwapper swapperGenericPT = new PendlePTGenericLevSwapper(
            ICoreBorrow(CORE_BORROW),
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(ANGLE_ROUTER),
            IMorpho(MORPHO_BLUE)
        );

        console.log("Successfully deployed generic PT swapper: ", address(swapperGenericPT));

        vm.stopBroadcast();
    }
}
