// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "borrow-staked/interfaces/external/curve/IMetaPoolBase.sol";

uint256 constant N_COINS = 2;

//solhint-disable
interface IMetaPool2WithReturn is IMetaPoolBase {
    function remove_liquidity_one_coin(
        uint256 _burn_amount,
        int128 i,
        uint256 _min_received
    ) external returns (uint256);

    function remove_liquidity(
        uint256 _burn_amount,
        uint256[N_COINS] memory _min_amounts
    ) external returns (uint256[N_COINS] memory);

    function remove_liquidity(
        uint256 _burn_amount,
        uint256[N_COINS] memory _min_amounts,
        address _receiver
    ) external returns (uint256[N_COINS] memory);

    function remove_liquidity_imbalance(
        uint256[N_COINS] memory _amounts,
        uint256 _max_burn_amount
    ) external returns (uint256);

    function remove_liquidity_imbalance(
        uint256[N_COINS] memory _amounts,
        uint256 _max_burn_amount,
        address _receiver
    ) external returns (uint256);
}
