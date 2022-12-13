// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "borrow/interfaces/ILiquidityGauge.sol";

interface ILiquidityGaugeComplete is ILiquidityGauge {
    //solhint-disable-next-line
    function reward_count() external view returns (uint256);

    //solhint-disable-next-line
    function reward_tokens(uint256) external view returns (address);
}
