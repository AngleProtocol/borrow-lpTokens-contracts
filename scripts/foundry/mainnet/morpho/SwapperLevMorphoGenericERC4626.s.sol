// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import "borrow/interfaces/IAngleRouterSidechain.sol";
import "borrow/interfaces/external/uniswap/IUniswapRouter.sol";
import { ERC4626GenericLevSwapper } from "borrow-staked/swapper/LevSwapper/ERC4626GenericLevSwapper.sol";
import "../MainnetConstants.s.sol";
import { IMorpho } from "morpho-blue/interfaces/IMorpho.sol";
import "borrow/interfaces/ICoreBorrow.sol";

contract ERC4626SwapperLevMorphoGenericERC4626 is Script, MainnetConstants, StdCheats, StdAssertions {
    ICoreBorrow coreBorrow;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        vm.startBroadcast(deployerPrivateKey);

        coreBorrow = ICoreBorrow(CORE_BORROW);
        // coreBorrow = new MockCoreBorrow();
        // coreBorrow.toggleGuardian(deployer);

        ERC4626GenericLevSwapper swapperGenericERC4626 = new ERC4626GenericLevSwapper(
            ICoreBorrow(CORE_BORROW),
            IUniswapV3Router(UNI_V3_ROUTER),
            ONE_INCH,
            IAngleRouterSidechain(ANGLE_ROUTER),
            IMorpho(MORPHO_BLUE)
        );

        console.log("Successfully deployed generic ERC4626 swapper: ", address(swapperGenericERC4626));

        vm.stopBroadcast();
    }
}
