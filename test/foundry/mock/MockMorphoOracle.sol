// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

import "morpho-blue/interfaces/IOracle.sol";

contract MockMorphoOracle is IOracle {
    uint256 public rate;

    /// @notice Initiate with a fixe change rate
    constructor(uint256 rate_) {
        rate = rate_;
    }

    /// @notice Mock read
    function price() external view returns (uint256) {
        return rate;
    }

    /// @notice change oracle rate
    function update(uint256 newRate) external {
        rate = newRate;
    }
}
