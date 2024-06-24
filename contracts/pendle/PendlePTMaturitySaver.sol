// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.12;

import { UNIT, UD60x18, ud } from "prb/math/UD60x18.sol";
import "borrow-staked/interfaces/external/pendle/IPMarketV3.sol";
import "borrow-staked/interfaces/external/pendle/IStandardizedYield.sol";
import "borrow-staked/interfaces/external/pendle/IPYieldTokenV2.sol";
import { PendlePYOracleLib } from "pendle/oracles/PendlePYOracleLib.sol";

/// @title PendlePTMaturitySaver
/// @author @GuillaumeNervoXS
/// @notice Automate PT redeeming at maturity to not missed out on any yield. While your PT are not redeem you are losing
/// the yield since maturity was reached. This contract will automate PT redeeming at maturity without loss of trust.
contract PendlePTMaturitySaver {
    uint256 public constant BASE_18 = 1 ether;
    uint256 public constant YEAR = 365 days;
    // @notice The minimum amount taken as management fee to recover the PT on time
    uint256 public constant RATIO_TO_DONATE = 0.001 ether;
    // @notice Address receiving the donation
    address public receiver;

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                        EVENTS                                                      
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    event MaxImpliedRateUpdated(uint256 _maxImpliedRate);
    event TwapPTDurationUpdated(uint256 _twapDuration);

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                        ERRORS                                                      
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    error TooEarlyMaturity();

    constructor(address _receiver) {
        receiver = _receiver;
    }

    function recoverYieldBearing(address owner, IPYieldTokenV2 yt) external {
        if (sy.expiry() < block.timestamp) revert TooEarlyMaturity();
        IERC20 pt = IERC20(yt.PT());
        _recoverFromPT(owner, yt, pt);
    }

    function recoverReceiver(IERC20 sy) external {
        sy.safeTransfer(receiver, sy.balanceOf(address(this)));
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                       INTERNAL                                                     
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    function _recoverFromPT(
        address owner,
        IPYieldTokenV2 yt,
        IERC20 pt
    ) internal view virtual returns (uint256, uint256) {
        pt.safeTransfer(address(yt), pt.balanceOf(owner));
        uint256 amountSyOut = yt.redeemPY(address(this));
        amountSyOut = (amountSyOut * (BASE_18 - RATIO_TO_DONATE)) / BASE_18;
        sy.safeTransfer(owner, amountSyOut);
    }
}
