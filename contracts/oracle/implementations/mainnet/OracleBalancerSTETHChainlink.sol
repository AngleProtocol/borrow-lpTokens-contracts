// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "borrow/oracle/BaseOracleChainlinkMulti.sol";
import "../../../interfaces/external/balancer/IBalancerStablePool.sol";

/// @title OracleBalancerSTETHChainlink
/// @author Angle Labs, Inc.
/// @notice Gives a lower bound of the price of the Balancer WETH/WSTETH in Euro in base 18
contract OracleBalancerSTETHChainlink is BaseOracleChainlinkMulti {
    string public constant DESCRIPTION = "B-stETH-STABLE/EUR Oracle";
    IBalancerStablePool public constant STETHBPT = IBalancerStablePool(0x32296969Ef14EB0c6d29669C550D4a0449130230);

    /// @notice Constructor of the contract
    /// @param _stalePeriod Minimum feed update frequency for the oracle to not revert
    /// @param _treasury Treasury associated to the `VaultManager` which reads from this feed
    constructor(uint32 _stalePeriod, address _treasury) BaseOracleChainlinkMulti(_stalePeriod, _treasury) {}

    function circuitChainlink() public pure returns (AggregatorV3Interface[] memory) {
        AggregatorV3Interface[] memory circuitChainlink_ = new AggregatorV3Interface[](3);
        // Chainlink stETH/USD address
        circuitChainlink_[0] = AggregatorV3Interface(0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8);
        // Chainlink ETH/USD address
        circuitChainlink_[1] = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        // Chainlink EUR/USD address
        circuitChainlink_[2] = AggregatorV3Interface(0xb49f677943BC038e9857d61E7d053CaA2C1734C1);
        return circuitChainlink_;
    }

    /// @inheritdoc IOracle
    function read() external view override returns (uint256 quoteAmount) {
        AggregatorV3Interface[] memory _circuitChainlink = circuitChainlink();
        // We use 0 decimals when reading fees through `readChainlinkFeed` since all feeds have 8 decimals
        // and the rate of the Balancer pool is given in 18 decimals, just like the amount of decimals
        // of the BPT token
        uint256 stETHPrice = _readChainlinkFeed(1, _circuitChainlink[0], 1, 0);
        uint256 ethPrice = _readChainlinkFeed(1, _circuitChainlink[1], 1, 0);
        // Picking the minimum price between stETH and ETH, multiplying it by the pool's rate
        ethPrice = ethPrice >= stETHPrice ? stETHPrice : ethPrice;
        quoteAmount = _readChainlinkFeed((STETHBPT.getRate() * ethPrice), _circuitChainlink[2], 0, 0);
    }
}
