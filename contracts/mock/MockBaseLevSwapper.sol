// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/BaseLevSwapper.sol";
import { MockBorrowStaker } from "borrow-staked/mock/MockBorrowStaker.sol";

/// @title MockBaseLevSwapper
/// @author Angle Labs, Inc.
contract MockBaseLevSwapper is BaseLevSwapper {
    IBorrowStaker internal _staker;
    IERC20 internal _asset;

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter,
        IBorrowStaker staker_
    ) BaseLevSwapper(_core, _uniV3Router, _aggregator, _angleRouter) {
        _staker = staker_;
        _asset = staker_.asset();
        _changeAllowance(_asset, address(staker_), type(uint256).max);
    }

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public view override returns (IBorrowStaker) {
        return _staker;
    }

    /// @inheritdoc BaseLevSwapper
    function _add(bytes memory) internal view override returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    /// @inheritdoc BaseLevSwapper
    function _remove(uint256, bytes memory) internal override {}
}
