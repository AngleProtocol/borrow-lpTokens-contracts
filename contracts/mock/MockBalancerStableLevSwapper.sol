// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.17;

import "borrow-staked/swapper/LevSwapper/balancer/implementations/mainnet/BalancerLevSwapperSTETH.sol";

/// @title MockBalancerStableLevSwapper
/// @author Angle Labs, Inc.
contract MockBalancerStableLevSwapper is BalancerLevSwapperSTETH {
    IBorrowStaker internal _angleStaker;

    constructor(
        ICoreBorrow _core,
        IUniswapV3Router _uniV3Router,
        address _aggregator,
        IAngleRouterSidechain _angleRouter,
        IBorrowStaker angleStaker_
    ) BalancerLevSwapperSTETH(_core, _uniV3Router, _aggregator, _angleRouter) {
        _angleStaker = angleStaker_;
    }

    /// @inheritdoc BaseLevSwapper
    function angleStaker() public view override returns (IBorrowStaker) {
        return _angleStaker;
    }

    function setAngleStaker(IBorrowStaker angleStaker_) public {
        _angleStaker = angleStaker_;
    }
}
