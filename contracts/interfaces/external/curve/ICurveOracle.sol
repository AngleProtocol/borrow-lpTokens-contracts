// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

interface ICurveOracle {
    //solhint-disable-next-line
    function lp_price() external view returns (uint256);
}
