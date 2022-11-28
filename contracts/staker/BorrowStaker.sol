// SPDX-License-Identifier: GPL-3.0

/*
                  *                                                  █                              
                *****                                               ▓▓▓                             
                  *                                               ▓▓▓▓▓▓▓                         
                                   *            ///.           ▓▓▓▓▓▓▓▓▓▓▓▓▓                       
                                 *****        ////////            ▓▓▓▓▓▓▓                          
                                   *       /////////////            ▓▓▓                             
                     ▓▓                  //////////////////          █         ▓▓                   
                   ▓▓  ▓▓             ///////////////////////                ▓▓   ▓▓                
                ▓▓       ▓▓        ////////////////////////////           ▓▓        ▓▓              
              ▓▓            ▓▓    /////////▓▓▓///////▓▓▓/////////       ▓▓             ▓▓            
           ▓▓                 ,////////////////////////////////////// ▓▓                 ▓▓         
        ▓▓                  //////////////////////////////////////////                     ▓▓      
      ▓▓                  //////////////////////▓▓▓▓/////////////////////                          
                       ,////////////////////////////////////////////////////                        
                    .//////////////////////////////////////////////////////////                     
                     .//////////////////////////██.,//////////////////////////█                     
                       .//////////////////////████..,./////////////////////██                       
                        ...////////////////███████.....,.////////////////███                        
                          ,.,////////////████████ ........,///////////████                          
                            .,.,//////█████████      ,.......///////████                            
                               ,..//████████           ........./████                               
                                 ..,██████                .....,███                                 
                                    .██                     ,.,█                                    
                                                                                                    
                                                                                                    
                                                                                                    
               ▓▓            ▓▓▓▓▓▓▓▓▓▓       ▓▓▓▓▓▓▓▓▓▓        ▓▓               ▓▓▓▓▓▓▓▓▓▓          
             ▓▓▓▓▓▓          ▓▓▓    ▓▓▓       ▓▓▓               ▓▓               ▓▓   ▓▓▓▓         
           ▓▓▓    ▓▓▓        ▓▓▓    ▓▓▓       ▓▓▓    ▓▓▓        ▓▓               ▓▓▓▓▓             
          ▓▓▓        ▓▓      ▓▓▓    ▓▓▓       ▓▓▓▓▓▓▓▓▓▓        ▓▓▓▓▓▓▓▓▓▓       ▓▓▓▓▓▓▓▓▓▓          
*/

pragma solidity 0.8.17;

import "./BorrowStakerStorage.sol";

/// @title BorrowStaker
/// @author Angle Labs, Inc.
/// @dev Staking contract keeping track of user rewards and minting a wrapper token
/// that can be hassle free on any other protocol without loosing the rewards
/// @dev If Angle is to accept a Curve LP token accruing CRV rewards, what is to be a collateral on the Borrowing module
/// is not going to be the LP token in itself, but the token corresponding to this type of contract
abstract contract BorrowStaker is BorrowStakerStorage, ERC20PermitUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice Initializes the `BorrowStaker`
    function initialize(ICoreBorrow _coreBorrow) external initializer {
        string memory name_ = IERC20Metadata(address(asset())).name();
        __ERC20Permit_init(name_);
        __ERC20_init_unchained(
            string(abi.encodePacked("Angle ", name_, " Staker")),
            string(abi.encodePacked("agstk-", IERC20Metadata(address(asset())).symbol()))
        );
        coreBorrow = _coreBorrow;
        _decimals = IERC20Metadata(address(asset())).decimals();
    }

    // ================================= MODIFIERS =================================

    /// @notice Checks whether the `msg.sender` has the governor role or not
    modifier onlyGovernor() {
        if (!coreBorrow.isGovernor(msg.sender)) revert NotGovernor();
        _;
    }

    /// @notice Checks whether the `msg.sender` has the governor role or the guardian role
    modifier onlyGovernorOrGuardian() {
        if (!coreBorrow.isGovernorOrGuardian(msg.sender)) revert NotGovernorOrGuardian();
        _;
    }

    /// @notice Checks whether the `msg.sender` has the governor role or the guardian role
    modifier onlyVaultManagers() {
        if (isCompatibleVaultManager[msg.sender] == 0) revert NotVaultManager();
        _;
    }

    // =============================== VIEW FUNCTIONS ==============================

    /// @notice Gets the list of all the `VaultManager` contracts which have this token
    /// as a collateral
    function getVaultManagers() external view returns (IVaultManagerListing[] memory) {
        return _vaultManagers;
    }

    // ============================= EXTERNAL FUNCTIONS ============================

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /// @notice Deposits the token to get the wrapped version
    /// @param amount Amount of token to be staked
    /// @param to Address for which the token is deposited
    function deposit(uint256 amount, address to) external returns (uint256) {
        // Need to transfer before minting or ERC777s could reenter.
        asset().safeTransferFrom(msg.sender, address(this), amount);
        _mint(to, amount);
        emit Deposit(msg.sender, to, amount);
        return amount;
    }

    /// @notice Withdraws the token from the same amount of wrapped token
    /// @param amount Amount of token to be unstaked
    /// @param from Address from which the token will be withdrawn
    /// @param to Address which will receive the token
    function withdraw(
        uint256 amount,
        address from,
        address to
    ) external returns (uint256) {
        if (msg.sender != from) {
            uint256 currentAllowance = allowance(from, msg.sender);
            if (currentAllowance < amount) revert TransferAmountExceedsAllowance();
            if (currentAllowance != type(uint256).max) {
                unchecked {
                    _approve(from, msg.sender, currentAllowance - amount);
                }
            }
        }
        _burn(from, amount);
        emit Withdraw(from, to, amount);
        asset().safeTransfer(to, amount);
        return amount;
    }

    /// @notice Claims earned rewards for user `from`
    /// @param from Address to claim for
    /// @return rewardAmounts Amounts of each reward token claimed by the user
    //solhint-disable-next-line
    function claim_rewards(address from) external returns (uint256[] memory) {
        address[] memory checkpointUser = new address[](1);
        checkpointUser[0] = address(from);
        return _checkpoint(checkpointUser, true);
    }

    /// @notice Checkpoints the rewards earned by user `from`
    /// @param from Address to checkpoint for
    function checkpoint(address from) external {
        address[] memory checkpointUser = new address[](1);
        checkpointUser[0] = address(from);
        _checkpoint(checkpointUser, false);
    }

    /// @notice Gets the full `asset` balance of `from`
    /// @param from Address to check the full balance of
    /// @dev The returned value takes into account the balance currently held by `from` and the balance held by `VaultManager`
    /// contracts on behalf of `from`
    function totalBalanceOf(address from) public view returns (uint256) {
        if (isCompatibleVaultManager[from] == 1) return 0;
        // If `from` is one of the whitelisted vaults, do not consider the rewards to not double count balances
        return balanceOf(from) + delegatedBalanceOf[from];
    }

    /// @notice Returns the exact amount that will be received if calling `claim_rewards(from)` for a specific reward token
    /// @param from Address to claim for
    /// @param _rewardToken Token to get rewards for
    function claimableRewards(address from, IERC20 _rewardToken) external view returns (uint256) {
        uint256 _totalSupply = totalSupply();
        uint256 newIntegral = _totalSupply != 0
            ? integral[_rewardToken] + (_rewardsToBeClaimed(_rewardToken) * BASE_PARAMS) / _totalSupply
            : integral[_rewardToken];
        uint256 newClaimable = (totalBalanceOf(from) * (newIntegral - integralOf[_rewardToken][from])) / BASE_PARAMS;
        return pendingRewardsOf[_rewardToken][from] + newClaimable;
    }

    // ============================ GOVERNANCE FUNCTIONS ===========================

    /// @notice Changes the core borrow contract
    /// @param _coreBorrow Address of the new core borrow contract
    function setCoreBorrow(ICoreBorrow _coreBorrow) external onlyGovernor {
        if (!_coreBorrow.isGovernor(msg.sender)) revert NotGovernor();
        coreBorrow = _coreBorrow;
    }

    /// @notice Adds to the tracking list a `vaultManager` which has as collateral the `asset`
    /// @param vaultManager Address of the new `vaultManager` to add to the list
    function addVaultManager(IVaultManagerListing vaultManager) external onlyGovernorOrGuardian {
        if (address(vaultManager.collateral()) != address(this) || isCompatibleVaultManager[address(vaultManager)] == 1)
            revert InvalidVaultManager();
        isCompatibleVaultManager[address(vaultManager)] = 1;
        _vaultManagers.push(vaultManager);
    }

    /// @notice Allows to recover any ERC20 token
    /// @param tokenAddress Address of the token to recover
    /// @param to Address of the contract to send collateral to
    /// @param amountToRecover Amount of collateral to transfer
    function recoverERC20(
        address tokenAddress,
        address to,
        uint256 amountToRecover
    ) external onlyGovernor {
        if (tokenAddress == address(asset())) revert InvalidToken();
        IERC20(tokenAddress).safeTransfer(to, amountToRecover);
        emit Recovered(tokenAddress, to, amountToRecover);
    }

    // ============================ RESTRICTED FUNCTIONS ===========================

    /// @notice Checkpoints the rewards earned by user `from` and then update its `totalBalance`
    /// @param from Address to checkpoint for
    /// @param amount Collateral amount balance increase/decrease for `from`
    /// @param add Whether the balance should be increased/decreased
    function checkpointFromVaultManager(
        address from,
        uint256 amount,
        bool add
    ) external onlyVaultManagers {
        address[] memory checkpointUser = new address[](1);
        checkpointUser[0] = address(from);
        _checkpoint(checkpointUser, false);
        if (add) delegatedBalanceOf[from] += amount;
        else delegatedBalanceOf[from] -= amount;
    }

    // ============================= INTERNAL FUNCTIONS ============================

    /// @inheritdoc ERC20Upgradeable
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 amount
    ) internal override {
        // Not claiming only if it is a deposit
        bool _claim = !(_from == address(0));

        address[] memory checkpointUser = new address[](2);
        checkpointUser[0] = _from;
        checkpointUser[1] = _to;
        _checkpoint(checkpointUser, _claim);
        // If the user is trying to withdraw we need to withdraw from the other protocol
        if (_to == address(0)) _withdrawFromProtocol(amount);
    }

    /// @notice Claims contracts rewards and checkpoints rewards for different `accounts`
    /// @param accounts Array of accounts we should checkpoint rewards for
    /// @param _claim Whether to claim for `accounts` the pending rewards
    /// @return rewardAmounts An array representing the rewards earned by the first address in the `accounts` array
    /// on each of the reward token
    /// @dev `rewardAmounts` is a one dimension array because n-dimensional arrays are only supported by internal functions
    /// The `accounts` array need to be ordered to get the rewards for a specific account
    /// @dev This function assumes that rewards are not distributed in one time without linear vesting. If not, rewards
    /// could be sent to the wrong owners
    function _checkpoint(address[] memory accounts, bool _claim) internal returns (uint256[] memory rewardAmounts) {
        if (_lastRewardsClaimed != block.timestamp) {
            _claimRewards();
            _lastRewardsClaimed = uint32(block.timestamp);
        }
        uint256 accountsLength = accounts.length;
        for (uint256 i; i < accountsLength; ++i) {
            if (accounts[i] == address(0) || isCompatibleVaultManager[accounts[i]] == 1) continue;
            if (i == 0) rewardAmounts = _checkpointRewardsUser(accounts[i], _claim);
            else _checkpointRewardsUser(accounts[i], _claim);
        }
    }

    /// @notice Checkpoints rewards earned by a user
    /// @param from Address to claim rewards from
    /// @param _claim Whether to claim or not the rewards
    /// @return rewardAmounts Amounts of the different reward tokens earned by the user
    function _checkpointRewardsUser(address from, bool _claim) internal returns (uint256[] memory rewardAmounts) {
        IERC20[] memory rewardTokens = _getRewards();
        uint256 rewardTokensLength = rewardTokens.length;
        rewardAmounts = new uint256[](rewardTokensLength);
        uint256 userBalance = totalBalanceOf(from);
        for (uint256 i; i < rewardTokensLength; ++i) {
            uint256 newClaimable = (userBalance * (integral[rewardTokens[i]] - integralOf[rewardTokens[i]][from])) /
                BASE_PARAMS;
            uint256 previousClaimable = pendingRewardsOf[rewardTokens[i]][from];
            if (_claim && previousClaimable + newClaimable != 0) {
                rewardTokens[i].safeTransfer(from, previousClaimable + newClaimable);
                pendingRewardsOf[rewardTokens[i]][from] = 0;
            } else if (newClaimable != 0) {
                pendingRewardsOf[rewardTokens[i]][from] += newClaimable;
            }
            integralOf[rewardTokens[i]][from] = integral[rewardTokens[i]];
            rewardAmounts[i] = previousClaimable + newClaimable;
        }
    }

    /// @notice Adds the contract claimed rewards to the distributed rewards
    /// @param rewardToken Reward token that must be updated
    /// @param amount Amount to add to the claimable rewards
    function _updateRewards(IERC20 rewardToken, uint256 amount) internal {
        uint256 _totalSupply = totalSupply();
        if (_totalSupply != 0) integral[rewardToken] += (amount * BASE_PARAMS) / _totalSupply;
    }

    /// @notice Changes allowance of this contract for a given token
    /// @param token Address of the token for which allowance should be changed
    /// @param spender Address to approve
    /// @param amount Amount to approve
    function _changeAllowance(
        IERC20 token,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = token.allowance(address(this), spender);
        if (currentAllowance < amount) token.safeIncreaseAllowance(spender, type(uint256).max - currentAllowance);
    }

    // ============================= VIRTUAL FUNCTIONS =============================

    /// @notice Underlying token to be staked
    function asset() public virtual returns (IERC20);

    /// @notice Claims all available rewards and increases the associated integral
    function _claimRewards() internal virtual;

    /// @notice Returns a list of all reward tokens supported by this contract
    function _getRewards() internal view virtual returns (IERC20[] memory reward);

    /// @notice Withdraws the staking token from the protocol rewards contract
    function _withdrawFromProtocol(uint256 amount) internal virtual;

    /// @notice Checks all unclaimed rewards in `rewardToken`
    /// @dev For some `rewardToken` this may not be precise (i.e lower bound) on what can be claimed
    function _rewardsToBeClaimed(IERC20 rewardToken) internal view virtual returns (uint256 amount);
}
