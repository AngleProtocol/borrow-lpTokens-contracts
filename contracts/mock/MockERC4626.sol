// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract MockERC4626 is ERC4626 {
    uint256 public rate;

    /// @notice Initiate with a fixe change rate
    constructor(IERC20Metadata asset_, uint256 rate_) ERC4626(asset_) ERC20("MockERC4626", "MERC4626") {
        rate = rate_;
    }

    function convertToAssets(uint256 shares) public view virtual override returns (uint256 assets) {
        return rate;
    }

    function setRate(uint256 rate_) public {
        rate = rate_;
    }
}
