// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "borrow/oracle/BaseOracleChainlinkMulti.sol";
import "borrow-staked/interfaces/external/curve/ICurveCryptoSwapPool.sol";

/// @title Oracle2PoolEURChainlinkArbitrum
/// @author Angle Labs, Inc.
/// @notice Gives a lower bound of the price of Curve 2Pool (Arbitrum) in Euro in base 18
contract Oracle2PoolEURChainlinkArbitrum is BaseOracleChainlinkMulti {
    string public constant DESCRIPTION = "2CRV/EUR Oracle";
    ICurveCryptoSwapPool public constant TwoPool = ICurveCryptoSwapPool(0x7f90122BF0700F9E7e1F688fe926940E8839F353);

    /// @notice Constructor of the contract
    /// @param _stalePeriod Minimum feed update frequency for the oracle to not revert
    /// @param _treasury Treasury associated to the `VaultManager` which reads from this feed
    constructor(uint32 _stalePeriod, address _treasury) BaseOracleChainlinkMulti(_stalePeriod, _treasury) {}

    function circuitChainlink() public pure override returns (AggregatorV3Interface[] memory) {
        AggregatorV3Interface[] memory _circuitChainlink = new AggregatorV3Interface[](3);
        // Chainlink USDT/USD address
        _circuitChainlink[0] = AggregatorV3Interface(0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7);
        // Chainlink USDC/USD address
        _circuitChainlink[1] = AggregatorV3Interface(0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3);
        // Chainlink EUR/USD address
        _circuitChainlink[2] = AggregatorV3Interface(0xA14d53bC1F1c0F31B4aA3BD109344E5009051a84);
        return _circuitChainlink;
    }

    /// @inheritdoc IOracle
    function read() external view override returns (uint256 quoteAmount) {
        AggregatorV3Interface[] memory _circuitChainlink = circuitChainlink();
        // We use 0 decimals when reading fees through `readChainlinkFeed` since all feeds have 8 decimals
        // and the virtual price of the Curve pool is given in 18 decimals, just like the amount of decimals
        // of the 2Pool token
        uint256 usdtPrice = _readChainlinkFeed(1, _circuitChainlink[0], 1, 0);
        uint256 usdcPrice = _readChainlinkFeed(1, _circuitChainlink[1], 1, 0);
        // Picking the minimum price between USDT and USDC, multiplying it by the pool's virtual price
        usdcPrice = usdcPrice >= usdtPrice ? usdtPrice : usdcPrice;
        quoteAmount = _readChainlinkFeed((TwoPool.get_virtual_price() * usdcPrice), _circuitChainlink[2], 0, 0);
    }
}
