// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { stdStorage, StdStorage } from "forge-std/Test.sol";
import "../BaseTest.test.sol";
import { VaultManagerListing } from "../../../contracts/vaultManager/VaultManagerListing.sol";
import { ActionType } from "../../../contracts/interfaces/IVaultManager.sol";
import "../../../contracts/mock/MockTreasury.sol";
import { MockBorrowStaker, MockBorrowStakerReset, BorrowStakerStorage } from "../../../contracts/mock/MockBorrowStaker.sol";
import "../../../contracts/mock/MockOracle.sol";
import "../../../contracts/mock/MockTokenPermit.sol";
import "../../../contracts/mock/MockCoreBorrow.sol";
import { MockAgToken } from "../../../contracts/mock/MockAgToken.sol";
import { AngleBorrowHelpers } from "../../../contracts/ui-helpers/AngleBorrowHelpers.sol";

/// @notice Data stored to track someone's loan (or equivalently called position)
struct VaultList {
    uint256[] _aliceList;
    uint256[] _bobList;
    uint256[] _charlieList;
    uint256[] _dylanList;
}

contract VaultManagerListingTest is BaseTest {
    using stdStorage for StdStorage;

    address internal _hacker = address(uint160(uint256(keccak256(abi.encodePacked("hacker")))));
    address internal _contractStableMaster =
        address(uint160(uint256(keccak256(abi.encodePacked("_contractStableMaster")))));

    VaultManagerListing internal _contractVaultManager;
    MockCoreBorrow internal _contractCoreBorrow;
    MockTreasury internal _contractTreasury;
    MockAgToken internal _contractAgToken;
    MockBorrowStakerReset public stakerImplementation;
    MockBorrowStakerReset public staker;
    AngleBorrowHelpers public helperImplementation;
    AngleBorrowHelpers public helper;
    MockTokenPermit public rewardToken;

    MockTokenPermit internal _collateral;
    MockOracle internal _oracle;

    // need to be reset at the beginning of every test
    mapping(address => uint256[]) public ownerListVaults;

    uint256 public constant ORACLE_VALUE = 5 ether;
    uint64 public constant CF = 0.8e9;
    uint8 public decimalToken = 18;
    uint8 public decimalReward = 6;
    uint256 public maxTokenAmount = 10**15 * 10**decimalToken;
    uint256 public rewardAmount = 10**2 * 10**(decimalReward);
    uint256 public constant TRANSFER_LENGTH = 50;
    uint256 public constant REWARDS_LENGTH = 50;

    function setUp() public override {
        super.setUp();

        delete ownerListVaults[_alice];
        delete ownerListVaults[_bob];
        delete ownerListVaults[_charlie];
        delete ownerListVaults[_dylan];

        _contractAgToken = new MockAgToken();
        vm.store(address(_contractAgToken), bytes32(uint256(0)), bytes32(uint256(0)));
        _contractAgToken.initialize("agEUR", "agEUR", address(_contractStableMaster));

        _contractCoreBorrow = new MockCoreBorrow();
        vm.store(address(_contractCoreBorrow), bytes32(uint256(0)), bytes32(uint256(0)));
        _contractCoreBorrow.toggleGovernor(_GOVERNOR);
        _contractCoreBorrow.toggleGuardian(_GUARDIAN);

        _contractTreasury = new MockTreasury(_contractCoreBorrow, _contractAgToken);

        _oracle = new MockOracle(ORACLE_VALUE, _contractTreasury);

        _collateral = new MockTokenPermit("Name", "SYM", decimalToken);
        rewardToken = new MockTokenPermit("reward", "rwrd", decimalReward);

        stakerImplementation = new MockBorrowStakerReset();
        staker = MockBorrowStakerReset(
            deployUpgradeable(
                address(stakerImplementation),
                abi.encodeWithSelector(staker.setAsset.selector, _collateral)
            )
        );
        staker.initialize(coreBorrow);
        staker.setRewardToken(rewardToken);

        _contractVaultManager = new VaultManagerListing();
        vm.store(address(_contractVaultManager), bytes32(uint256(0)), bytes32(uint256(0)));

        // No protocol revenue for easier computation
        VaultParameters memory params = VaultParameters({
            debtCeiling: type(uint256).max / 10**27,
            collateralFactor: CF,
            targetHealthFactor: 1.1e9,
            interestRate: 0,
            liquidationSurcharge: 1e9,
            maxLiquidationDiscount: 0.1e9,
            whitelistingActivated: false,
            baseBoost: 1e9
        });
        _contractVaultManager.initialize(_contractTreasury, IERC20(address(staker)), _oracle, params, "wETH");

        vm.prank(_GOVERNOR);
        _contractAgToken.setUpTreasury(address(_contractTreasury));

        helperImplementation = new AngleBorrowHelpers();
        helper = new AngleBorrowHelpers();

        vm.startPrank(_GOVERNOR);
        _contractVaultManager.togglePause();
        _contractTreasury.addVaultManager(address(_contractVaultManager));
        staker.addVaultManager(IVaultManagerListing(address(_contractVaultManager)));
        vm.stopPrank();

        vm.prank(address(_contractTreasury));
        _contractAgToken.addMinter(_GOVERNOR);
    }

    function testVaultListAndCollateralAmounts(
        uint256[TRANSFER_LENGTH] memory accounts,
        uint256[TRANSFER_LENGTH] memory initiators,
        uint256[TRANSFER_LENGTH] memory tos,
        uint256[TRANSFER_LENGTH] memory actionTypes,
        uint256[TRANSFER_LENGTH] memory amounts
    ) public {
        uint256[5] memory collateralVaultAmounts;
        uint256[5] memory collateralIdleAmounts;

        amounts[0] = bound(amounts[0], 1, maxTokenAmount);
        _openVault(_alice, _alice, amounts[0]);
        collateralVaultAmounts[0] += amounts[0];
        ownerListVaults[_alice].push(_contractVaultManager.vaultIDCount());

        for (uint256 i = 1; i < amounts.length; ++i) {
            (uint256 randomIndex, address account) = _getAccountByIndex(accounts[i]);
            (, address initiator) = _getAccountByIndex(initiators[i]);
            uint256 action = bound(actionTypes[i], 0, 8);
            if (ownerListVaults[account].length == 0) action = 0;

            if (action == 0) {
                // just deposit into the staker
                amounts[i] = bound(amounts[i], 0, maxTokenAmount);
                (uint256 randomIndexTo, address to) = _getAccountByIndex(tos[i]);
                deal(address(_collateral), account, amounts[i]);
                vm.startPrank(account);
                // first get the true collateral
                _collateral.approve(address(staker), amounts[i]);
                staker.deposit(amounts[i], to);
                collateralIdleAmounts[randomIndexTo] += amounts[i];
                vm.stopPrank();
            } else if (action == 1) {
                // just withdraw from the staker
                amounts[i] = bound(amounts[i], 1, BASE_PARAMS);
                (, address to) = _getAccountByIndex(tos[i]);
                uint256 withdrawnDirectly = (amounts[i] * staker.balanceOf(account)) / BASE_PARAMS;
                vm.startPrank(account);
                staker.withdraw(withdrawnDirectly, account, to);
                collateralIdleAmounts[randomIndex] -= withdrawnDirectly;
                vm.stopPrank();
            } else if (action == 2) {
                uint256 amount = bound(amounts[i], 1, maxTokenAmount);
                (uint256 randomIndexTo, address to) = _getAccountByIndex(tos[i]);
                _openVault(account, to, amount);
                collateralVaultAmounts[randomIndexTo] += amount;
                ownerListVaults[to].push(_contractVaultManager.vaultIDCount());
            } else if (action == 3) {
                uint256[] storage vaultIDs = ownerListVaults[account];
                amounts[i] = bound(amounts[i], 0, vaultIDs.length - 1);
                (uint256 randomIndexTo, address to) = _getAccountByIndex(tos[i]);
                uint256 vaultID = vaultIDs[amounts[i]];
                uint256 collateralAmount = _closeVault(account, initiator, to, vaultID);
                collateralVaultAmounts[randomIndex] -= collateralAmount;
                collateralIdleAmounts[randomIndexTo] += collateralAmount;
                _removeVaultFromList(vaultIDs, vaultID);
            } else if (action == 4) {
                uint256[] storage vaultIDs = ownerListVaults[account];
                (uint256 randomIndexTo, address to) = _getAccountByIndex(tos[i]);
                amounts[i] = bound(amounts[i], 0, vaultIDs.length - 1);
                uint256 vaultID = vaultIDs[amounts[i]];
                uint256 vaultDebt = _contractVaultManager.getVaultDebt(vaultID);
                (uint256 collateralAmount, ) = _contractVaultManager.vaultData(vaultID);
                collateralVaultAmounts[randomIndex] -= collateralAmount;
                collateralVaultAmounts[randomIndexTo] += collateralAmount;
                vm.startPrank(account);
                _contractVaultManager.transferFrom(account, to, vaultID);
                // so that if the other one close it he has enough
                // this doesn't work if the debt increased (this works because the interest rate is set to 0),
                // we would need to increase artificially the owner balance too
                _contractAgToken.transfer(to, vaultDebt);
                vm.stopPrank();
                _removeVaultFromList(vaultIDs, vaultID);
                uint256[] storage vaultToIDs = ownerListVaults[to];
                _addVaultFromList(vaultToIDs, vaultID);
            } else if (action == 5) {
                uint256[] storage vaultIDs = ownerListVaults[account];
                amounts[i] = bound(amounts[i], 1, maxTokenAmount);
                tos[i] = bound(tos[i], 0, vaultIDs.length - 1);
                uint256 vaultID = vaultIDs[tos[i]];
                _addToVault(account, initiator, vaultID, amounts[i]);
                collateralVaultAmounts[randomIndex] += amounts[i];
            } else if (action == 6) {
                uint256[] storage vaultIDs = ownerListVaults[account];
                tos[i] = bound(tos[i], 0, vaultIDs.length - 1);
                uint256 vaultID = vaultIDs[tos[i]];
                (uint256 randomIndexInitiator, ) = _getAccountByIndex(initiators[i]);
                uint256 collateralAmount = _removeFromVault(account, initiator, vaultID, amounts[i]);
                collateralVaultAmounts[randomIndex] -= collateralAmount;
                collateralIdleAmounts[randomIndexInitiator] += collateralAmount;
            } else if (action == 7) {
                uint256[] storage vaultIDs = ownerListVaults[account];
                amounts[i] = bound(amounts[i], 0, vaultIDs.length - 1);
                uint256 vaultID = vaultIDs[amounts[i]];
                (bool liquidated, uint256 collateralAmount) = _liquidateVault(_hacker, vaultID);
                collateralVaultAmounts[randomIndex] -= collateralAmount;
                collateralIdleAmounts[4] += collateralAmount;
            } else if (action == 8) {
                // partial liquidation
                uint256[] storage vaultIDs = ownerListVaults[account];
                amounts[i] = bound(amounts[i], 0, vaultIDs.length - 1);
                uint256 vaultID = vaultIDs[amounts[i]];
                (bool fullLiquidation, uint256 collateralAmount) = _partialLiquidationVault(_hacker, vaultID);
                collateralVaultAmounts[randomIndex] -= collateralAmount;
                collateralIdleAmounts[4] += collateralAmount;
            }
            for (uint256 k = 0; k < 5; k++) {
                address checkedAccount = k == 0 ? _alice : k == 1 ? _bob : k == 2 ? _charlie : k == 3
                    ? _dylan
                    : _hacker;
                assertEq(
                    collateralVaultAmounts[k] + collateralIdleAmounts[k],
                    staker.balanceOf(checkedAccount) + staker.delegatedBalanceOf(checkedAccount)
                );
                assertEq(collateralVaultAmounts[k], staker.delegatedBalanceOf(checkedAccount));
                assertEq(collateralIdleAmounts[k], staker.balanceOf(checkedAccount));
                assertEq(collateralVaultAmounts[k] + collateralIdleAmounts[k], staker.totalBalanceOf(checkedAccount));

                uint256[] memory vaultIDs = ownerListVaults[checkedAccount];
                (uint256[] memory helperVaultIDs, uint256 count) = helper.getControlledVaults(
                    IVaultManager(address(_contractVaultManager)),
                    checkedAccount
                );
                _compareLists(vaultIDs, helperVaultIDs, count);
                if (checkedAccount == _hacker) assertEq(vaultIDs.length, 0);
            }
        }
    }

    function testBorrowStakerWithVaultManager(
        uint256[REWARDS_LENGTH] memory accounts,
        uint256[REWARDS_LENGTH] memory initiators,
        uint256[REWARDS_LENGTH] memory tos,
        uint256[REWARDS_LENGTH] memory actionTypes,
        uint256[REWARDS_LENGTH] memory amounts
    ) public {
        uint256[5] memory pendingRewards;
        // deal(address(rewardToken), address(staker), type(uint256).max);

        for (uint256 i; i < amounts.length; ++i) {
            vm.warp(block.number + 1);
            vm.roll(block.timestamp + 10);

            _simulateVaultInteraction(accounts[i], initiators[i], tos[i], actionTypes[i], amounts[i]);

            {
                uint256 totSupply = staker.totalSupply();
                uint256 _rewardAmount = staker.rewardAmount();
                if (totSupply > 0) {
                    pendingRewards[0] += (staker.totalBalanceOf(_alice) * _rewardAmount) / totSupply;
                    pendingRewards[1] += (staker.totalBalanceOf(_bob) * _rewardAmount) / totSupply;
                    pendingRewards[2] += (staker.totalBalanceOf(_charlie) * _rewardAmount) / totSupply;
                    pendingRewards[3] += (staker.totalBalanceOf(_dylan) * _rewardAmount) / totSupply;
                }
            }

            for (uint256 k = 0; k < 4; k++) {
                address checkedAccount = k == 0 ? _alice : k == 1 ? _bob : k == 2 ? _charlie : k == 3
                    ? _dylan
                    : _hacker;
                assertApproxEqAbs(
                    rewardToken.balanceOf(checkedAccount) + staker.claimableRewards(checkedAccount, rewardToken),
                    pendingRewards[k],
                    10**(decimalReward - 4)
                );
            }
        }
    }

    // function testTrickyInflateBalanceAtCheckpoint() public {
    //     uint256[3] memory actionTypes = [];
    //     uint256[3] memory accounts = [];
    //     uint256[3] memory tos = [];
    //     uint256[3] memory amounts = [];

    //     uint256[5] memory pendingRewards;

    //     for (uint256 i; i < amounts.length; ++i) {
    //         vm.warp(block.number + 1);
    //         vm.roll(block.timestamp + 10);

    //         _simulateVaultInteraction(accounts[i], tos[i], actionTypes[i], amounts[i]);

    //         {
    //             uint256 totSupply = staker.totalSupply();
    //             uint256 _rewardAmount = staker.rewardAmount();
    //             if (totSupply > 0) {
    //                 pendingRewards[0] += (staker.totalBalanceOf(_alice) * _rewardAmount) / totSupply;
    //                 pendingRewards[1] += (staker.totalBalanceOf(_bob) * _rewardAmount) / totSupply;
    //                 pendingRewards[2] += (staker.totalBalanceOf(_charlie) * _rewardAmount) / totSupply;
    //                 pendingRewards[3] += (staker.totalBalanceOf(_dylan) * _rewardAmount) / totSupply;
    //             }
    //         }

    //         for (uint256 k = 0; k < 4; k++) {
    //             address checkedAccount = k == 0 ? _alice : k == 1 ? _bob : k == 2 ? _charlie : k == 3
    //                 ? _dylan
    //                 : _hacker;
    //             assertApproxEqAbs(
    //                 rewardToken.balanceOf(checkedAccount) + staker.claimableRewards(checkedAccount, rewardToken),
    //                 pendingRewards[k],
    //                 10**(decimalReward - 4)
    //             );
    //         }
    //     }
    // }

    // ============================= INTERNAL FUNCTIONS ============================

    function _getAccountByIndex(uint256 index) internal returns (uint256, address) {
        uint256 randomIndex = bound(index, 0, 3);
        address account = randomIndex == 0 ? _alice : randomIndex == 1 ? _bob : randomIndex == 2 ? _charlie : _dylan;
        return (randomIndex, account);
    }

    function _simulateVaultInteraction(
        uint256 accountInt,
        uint256 initiatorInt,
        uint256 to,
        uint256 actionType,
        uint256 amount
    ) internal {
        (, address account) = _getAccountByIndex(accountInt);
        (, address initiator) = _getAccountByIndex(initiatorInt);
        uint256 action = bound(actionType, 0, 9);

        (uint256[] memory vaultIDs, uint256 count) = helper.getControlledVaults(
            IVaultManager(address(_contractVaultManager)),
            account
        );
        if (count == 0) action = 3;

        if (action == 0) {
            // just deposit into the staker
            amount = bound(amount, 0, maxTokenAmount);
            (, address sentTo) = _getAccountByIndex(to);
            deal(address(_collateral), account, amount);
            vm.startPrank(account);
            // first get the true collateral
            _collateral.approve(address(staker), amount);
            staker.deposit(amount, sentTo);
            vm.stopPrank();
        } else if (action == 1) {
            // just withdraw into the staker
            amount = bound(amount, 1, BASE_PARAMS);
            (, address sentTo) = _getAccountByIndex(to);
            uint256 withdrawnDirectly = (amount * staker.balanceOf(account)) / BASE_PARAMS;
            vm.startPrank(account);
            staker.withdraw(withdrawnDirectly, account, sentTo);
            vm.stopPrank();
        } else if (action == 2) {
            // Acknowledge if needed the previous reward
            staker.checkpoint(address(0));
            // add a reward
            uint256 curBalance = rewardToken.balanceOf(address(staker));
            amount = bound(amount, 10000, 10_000_000 * 10**decimalReward);
            deal(address(rewardToken), address(staker), curBalance + amount);
            staker.setRewardAmount(amount);
        } else if (action == 3) {
            amount = bound(amount, 1, maxTokenAmount);
            (, address sentTo) = _getAccountByIndex(to);
            _openVault(account, sentTo, amount);
        } else if (action == 4) {
            amount = bound(amount, 0, count - 1);
            uint256 vaultID = vaultIDs[amount];
            (, address sentTo) = _getAccountByIndex(to);
            _closeVault(account, initiator, sentTo, vaultID);
        } else if (action == 5) {
            (, address sentTo) = _getAccountByIndex(to);
            amount = bound(amount, 0, count - 1);
            uint256 vaultID = vaultIDs[amount];
            uint256 vaultDebt = _contractVaultManager.getVaultDebt(vaultID);

            // to allow to interact with someone else vault
            if (account != initiator) {
                vm.startPrank(account);
                _contractVaultManager.setApprovalForAll(initiator, true);
                vm.stopPrank();
            }

            vm.prank(initiator);
            _contractVaultManager.transferFrom(account, sentTo, vaultID);

            vm.startPrank(account);
            // so that if the other one close it he has enough
            // this doesn't work if the debt increased, we would need to increase
            // artificially the owner balance too
            _contractAgToken.transfer(sentTo, vaultDebt);
            vm.stopPrank();

            if (account != initiator) {
                vm.startPrank(account);
                _contractVaultManager.setApprovalForAll(initiator, false);
                vm.stopPrank();
            }
        } else if (action == 6) {
            amount = bound(amount, 1, maxTokenAmount);
            to = bound(to, 0, count - 1);
            uint256 vaultID = vaultIDs[to];
            _addToVault(account, initiator, vaultID, amount);
        } else if (action == 7) {
            to = bound(to, 0, count - 1);
            uint256 vaultID = vaultIDs[to];
            uint256 removed = _removeFromVault(account, initiator, vaultID, amount);
            if (removed == 0) staker.checkpoint(address(0));
        } else if (action == 8) {
            amount = bound(amount, 0, count - 1);
            uint256 vaultID = vaultIDs[amount];
            (bool liquidated, ) = _liquidateVault(_hacker, vaultID);
            // Acknowledge rewards if nothing has been triggered
            if (!liquidated) staker.checkpoint(address(0));
        } else if (action == 9) {
            // partial liquidation
            amount = bound(amount, 0, count - 1);
            uint256 vaultID = vaultIDs[amount];
            (bool fullLiquidation, uint256 collateralAmount) = _partialLiquidationVault(_hacker, vaultID);
            // Acknowledge rewards if nothing has been triggered
            if (!fullLiquidation && collateralAmount == 0) staker.checkpoint(address(0));
        }
    }

    function _openVault(
        address spender,
        address owner,
        uint256 amount
    ) internal {
        uint256 numberActions = 3;
        ActionType[] memory actions = new ActionType[](numberActions);
        actions[0] = ActionType.createVault;
        actions[1] = ActionType.addCollateral;
        actions[2] = ActionType.borrow;

        bytes[] memory datas = new bytes[](numberActions);
        datas[0] = abi.encode(owner);
        datas[1] = abi.encode(0, amount);
        // to be over the liquidation threshold
        datas[2] = abi.encode(0, (amount * ORACLE_VALUE) / 2 ether);

        // to allow to borrow for somebody else
        if (owner != spender) {
            vm.startPrank(owner);
            _contractVaultManager.setApprovalForAll(spender, true);
            vm.stopPrank();
        }

        deal(address(_collateral), spender, amount);
        vm.startPrank(spender);
        // first get the true collateral
        _collateral.approve(address(staker), amount);
        staker.deposit(amount, spender);
        // then open the vault
        staker.approve(address(_contractVaultManager), amount);
        _contractVaultManager.angle(actions, datas, spender, owner);
        vm.stopPrank();

        if (owner != spender) {
            vm.startPrank(owner);
            _contractVaultManager.setApprovalForAll(spender, false);
            vm.stopPrank();
        }
    }

    function _closeVault(
        address owner,
        address initiator,
        address to,
        uint256 vaultID
    ) internal returns (uint256 collateralAmount) {
        (collateralAmount, ) = _contractVaultManager.vaultData(vaultID);

        uint256 numberActions = 1;
        ActionType[] memory actions = new ActionType[](numberActions);
        actions[0] = ActionType.closeVault;

        bytes[] memory datas = new bytes[](numberActions);
        datas[0] = abi.encode(vaultID);

        // to allow to interact with someone else vault
        if (owner != initiator) {
            vm.startPrank(owner);
            _contractVaultManager.setApprovalForAll(initiator, true);
            vm.stopPrank();
        }

        vm.prank(owner);
        _contractAgToken.approve(initiator, type(uint256).max);

        vm.startPrank(initiator);
        _contractVaultManager.angle(actions, datas, owner, to);
        vm.stopPrank();

        vm.prank(owner);
        _contractAgToken.approve(initiator, 0);

        if (owner != initiator) {
            vm.startPrank(owner);
            _contractVaultManager.setApprovalForAll(initiator, false);
            vm.stopPrank();
        }
    }

    function _addToVault(
        address owner,
        address initiator,
        uint256 vaultID,
        uint256 amount
    ) internal {
        uint256 numberActions = 1;
        ActionType[] memory actions = new ActionType[](numberActions);
        actions[0] = ActionType.addCollateral;

        bytes[] memory datas = new bytes[](numberActions);
        datas[0] = abi.encode(vaultID, amount);

        // to allow to interact with someone else vault
        if (owner != initiator) {
            vm.startPrank(owner);
            _contractVaultManager.setApprovalForAll(initiator, true);
            vm.stopPrank();
        }

        deal(address(_collateral), initiator, amount);
        vm.startPrank(initiator);
        // first get the true collateral
        _collateral.approve(address(staker), amount);
        staker.deposit(amount, initiator);
        // then open the vault
        staker.approve(address(_contractVaultManager), amount);
        _contractVaultManager.angle(actions, datas, initiator, owner);
        vm.stopPrank();

        if (owner != initiator) {
            vm.startPrank(owner);
            _contractVaultManager.setApprovalForAll(initiator, false);
            vm.stopPrank();
        }
    }

    function _removeFromVault(
        address owner,
        address initiator,
        uint256 vaultID,
        uint256 amount
    ) internal returns (uint256 collateralAmount) {
        uint256 vaultDebt = _contractVaultManager.getVaultDebt(vaultID);
        (uint256 currentCollat, ) = _contractVaultManager.vaultData(vaultID);
        // Taking a buffer when withdrawing for rounding errors
        vaultDebt = (11 * ((((((vaultDebt * BASE_PARAMS) / CF + 1) * 10**decimalToken))) / ORACLE_VALUE + 1)) / 10;

        if (vaultDebt >= currentCollat || vaultDebt == 0) return 0;
        amount = bound(amount, 1, currentCollat - vaultDebt);

        uint256 numberActions = 1;
        ActionType[] memory actions = new ActionType[](numberActions);
        actions[0] = ActionType.removeCollateral;

        bytes[] memory datas = new bytes[](numberActions);
        datas[0] = abi.encode(vaultID, amount);

        // to allow to interact with someone else vault
        if (owner != initiator) {
            vm.startPrank(owner);
            _contractVaultManager.setApprovalForAll(initiator, true);
            vm.stopPrank();
        }

        vm.startPrank(initiator);
        _contractVaultManager.angle(actions, datas, initiator, initiator);
        vm.stopPrank();

        if (owner != initiator) {
            vm.startPrank(owner);
            _contractVaultManager.setApprovalForAll(initiator, false);
            vm.stopPrank();
        }

        return amount;
    }

    function _liquidateVault(address liquidator, uint256 vaultID) internal returns (bool, uint256) {
        // to be able to liquidate it fully
        uint256 vaultDebt = _contractVaultManager.getVaultDebt(vaultID);
        (uint256 currentCollat, ) = _contractVaultManager.vaultData(vaultID);
        if (currentCollat == 0) return (false, 0);
        {
            uint256 newOracleValue = (((vaultDebt * BASE_PARAMS) / CF) * 10**decimalToken) / currentCollat / 100;
            if (newOracleValue == 0) return (false, 0);
            _oracle.update(newOracleValue);
        }

        _internalLiquidateVault(liquidator, vaultID);
        _oracle.update(ORACLE_VALUE);
        return (true, currentCollat);
    }

    function _partialLiquidationVault(address liquidator, uint256 vaultID) internal returns (bool, uint256) {
        // to be able to liquidate it fully
        uint256 vaultDebt = _contractVaultManager.getVaultDebt(vaultID);
        (uint256 currentCollat, ) = _contractVaultManager.vaultData(vaultID);
        if (currentCollat == 0) return (false, 0);
        {
            uint256 newOracleValue = (((vaultDebt * BASE_PARAMS) / CF) * 10**decimalToken) / currentCollat;
            if (newOracleValue < 2) return (false, 0);
            else newOracleValue -= 1;
            _oracle.update(newOracleValue);
        }

        _internalLiquidateVault(liquidator, vaultID);
        _oracle.update(ORACLE_VALUE);
        (uint256 newCollat, ) = _contractVaultManager.vaultData(vaultID);
        return (newCollat == 0, currentCollat - newCollat);
    }

    function _internalLiquidateVault(address liquidator, uint256 vaultID) internal {
        LiquidationOpportunity memory liqOpp = _contractVaultManager.checkLiquidation(vaultID, liquidator);
        uint256 amountToReimburse = liqOpp.maxStablecoinAmountToRepay;

        uint256 numberActions = 1;
        uint256[] memory vaultIDs = new uint256[](numberActions);
        vaultIDs[0] = vaultID;
        uint256[] memory amounts = new uint256[](numberActions);
        amounts[0] = amountToReimburse;

        vm.prank(_GOVERNOR);
        _contractAgToken.mint(liquidator, amountToReimburse);

        vm.startPrank(liquidator);
        // can try with a to different than liquidator
        _contractVaultManager.liquidate(vaultIDs, amounts, liquidator, liquidator);
        vm.stopPrank();
    }

    /// @dev Not the most efficient way but to keep the vaultIDs ordered
    function _addVaultFromList(uint256[] storage vaultList, uint256 vaultID) internal {
        vaultList.push(vaultID);
        uint256 vaultListLength = vaultList.length;
        if (vaultListLength == 1) return;
        int256 i = int256(vaultListLength - 2);
        for (; i >= 0; i--) {
            if (vaultList[uint256(i)] > vaultID) vaultList[uint256(i) + 1] = vaultList[uint256(i)];
            else break;
        }
        vaultList[uint256(i + 1)] = vaultID;
    }

    /// @dev Not the most efficient way but to keep the vaultIDs ordered
    function _removeVaultFromList(uint256[] storage vaultList, uint256 vaultID) internal {
        uint256 vaultListLength = vaultList.length;
        bool indexMet;
        for (uint256 i; i < vaultListLength; ++i) {
            if (vaultList[i] == vaultID) indexMet = true;
            else if (indexMet) vaultList[i - 1] = vaultList[i];
        }
        vaultList.pop();
    }

    function _compareLists(
        uint256[] memory expectedVaultList,
        uint256[] memory vaultList,
        uint256 count
    ) internal {
        assertEq(count, expectedVaultList.length);
        for (uint256 i; i < count; ++i) {
            assertEq(vaultList[i], expectedVaultList[i]);
        }
    }

    function _logArray(
        uint256[] memory list,
        uint256 count,
        address owner
    ) internal view {
        console.log("owner: ", owner);
        count = count == type(uint256).max ? list.length : count;
        for (uint256 i; i < count; ++i) {
            console.log("owns vaultID: ", list[i]);
        }
    }
}
