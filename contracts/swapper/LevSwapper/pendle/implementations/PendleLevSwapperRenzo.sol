// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "../PendleLevSwapper.sol";

/// @author Angle Labs, Inc.
/// @notice Renzo PT ETH leverage swapper
contract PendleLevSwapperRenzo is PendleLevSwapper {
    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter
    ) PendleLevSwapper(_core, _uniV3Router, _aggregator, _angleRouter) {}

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public pure override returns (IBorrowStaker) {
        return IBorrowStaker(address(0));
    }

    /// @inheritdoc PendleLevSwapper
    function PT() public pure override returns (IERC20) {
        return IERC20(address(0xeEE8aED1957ca1545a0508AfB51b53cCA7e3c0d1));
    }

    /// @inheritdoc PendleLevSwapper
    function SY() public pure override returns (IStandardizedYield) {
        return IStandardizedYield(address(0x22E12A50e3ca49FB183074235cB1db84Fe4C716D));
    }

    /// @inheritdoc PendleLevSwapper
    function YT() public pure override returns (IPYieldTokenV2) {
        return IPYieldTokenV2(address(0x256Fb830945141f7927785c06b65dAbc3744213c));
    }

    /// @inheritdoc PendleLevSwapper
    function market() public pure override returns (IPMarketV3) {
        return IPMarketV3(address(0xDe715330043799D7a80249660d1e6b61eB3713B3));
    }

    /// @inheritdoc PendleLevSwapper
    function collateral() public pure override returns (IERC20) {
        return IERC20(address(0xbf5495Efe5DB9ce00f80364C8B423567e58d2110));
    }
}
