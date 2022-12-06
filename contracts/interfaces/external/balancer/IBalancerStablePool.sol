// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

interface IBalancerStablePool {
    /**
     * @dev This function returns the appreciation of one BPT relative to the
     * underlying tokens. This starts at 1 when the pool is created and grows over time
     */
    function getRate() external view returns (uint256);
}
