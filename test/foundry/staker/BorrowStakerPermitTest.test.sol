// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../BaseTest.test.sol";
import "../../../contracts/mock/MockTokenPermit.sol";
import { MockBorrowStaker, BorrowStakerStorage } from "../../../contracts/mock/MockBorrowStaker.sol";
import { SigUtils, Permit } from "../utils/SigUtils.sol";

contract BorrowStakerPermitTest is BaseTest {
    using stdStorage for StdStorage;

    MockTokenPermit public asset;
    MockBorrowStaker public stakerImplementation;
    MockBorrowStaker public staker;
    SigUtils public sigUtils;
    uint8 public decimalstaker = 18;
    uint256 public maxstakerAmount = 10**15 * 10**decimalstaker;

    uint256 public constant DEPOSIT_LENGTH = 10;
    uint256 public constant WITHDRAW_LENGTH = 10;
    uint256 public constant CLAIMABLE_LENGTH = 50;
    uint256 public constant CLAIM_LENGTH = 50;

    function setUp() public override {
        super.setUp();
        asset = new MockTokenPermit("agEUR", "agEUR", decimalstaker);
        stakerImplementation = new MockBorrowStaker();
        staker = MockBorrowStaker(
            deployUpgradeable(address(stakerImplementation), abi.encodeWithSelector(staker.setAsset.selector, asset))
        );
        staker.initialize(coreBorrow);
        sigUtils = new SigUtils(staker.DOMAIN_SEPARATOR());
    }

    // =================================== REVERT ==================================

    function testRevertExpiredPermit(
        uint256 ownerPrivateKey,
        uint256 spenderPrivateKey,
        uint256 amount,
        uint256 deadline
    ) public {
        address owner;
        address spender;
        (owner, spender, ownerPrivateKey, spenderPrivateKey) = _getAddresses(ownerPrivateKey, spenderPrivateKey);

        deadline = bound(deadline, 0, 1000 days);

        Permit memory permit = Permit({
            owner: owner,
            spender: spender,
            value: amount,
            nonce: staker.nonces(owner),
            deadline: deadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.warp(deadline + 1 seconds);

        vm.expectRevert("ERC20Permit: expired deadline");
        staker.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevertInvalidSigner(
        uint256 ownerPrivateKey,
        uint256 spenderPrivateKey,
        uint256 amount,
        uint256 deadline
    ) public {
        address owner;
        address spender;
        (owner, spender, ownerPrivateKey, spenderPrivateKey) = _getAddresses(ownerPrivateKey, spenderPrivateKey);

        deadline = bound(deadline, 1, 1000 days);

        Permit memory permit = Permit({
            owner: owner,
            spender: spender,
            value: amount,
            nonce: staker.nonces(owner),
            deadline: deadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(spenderPrivateKey, digest);

        vm.expectRevert("ERC20Permit: invalid signature");
        staker.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevertInvalidNonce(
        uint256 ownerPrivateKey,
        uint256 spenderPrivateKey,
        uint256 amount,
        uint256 deadline
    ) public {
        address owner;
        address spender;
        (owner, spender, ownerPrivateKey, spenderPrivateKey) = _getAddresses(ownerPrivateKey, spenderPrivateKey);

        deadline = bound(deadline, 1, 1000 days);

        Permit memory permit = Permit({ owner: owner, spender: spender, value: amount, nonce: 1, deadline: deadline });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        vm.expectRevert("ERC20Permit: invalid signature");
        staker.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testRevertSignatureReplay(
        uint256 ownerPrivateKey,
        uint256 spenderPrivateKey,
        uint256 amount,
        uint256 deadline
    ) public {
        address owner;
        address spender;
        (owner, spender, ownerPrivateKey, spenderPrivateKey) = _getAddresses(ownerPrivateKey, spenderPrivateKey);

        deadline = bound(deadline, 1, 1000 days);

        Permit memory permit = Permit({ owner: owner, spender: spender, value: amount, nonce: 0, deadline: deadline });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        staker.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.expectRevert("ERC20Permit: invalid signature");
        staker.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function testFailInvalidAllowance(
        uint256 ownerPrivateKey,
        uint256 spenderPrivateKey,
        uint256 amount,
        uint256 deadline
    ) public {
        address owner;
        address spender;
        (owner, spender, ownerPrivateKey, spenderPrivateKey) = _getAddresses(ownerPrivateKey, spenderPrivateKey);

        deadline = bound(deadline, 1, 1000 days);
        amount = bound(amount, 1, type(uint256).max);
        deal(address(staker), address(owner), amount);

        Permit memory permit = Permit({
            owner: owner,
            spender: spender,
            value: amount / 2,
            nonce: 0,
            deadline: deadline
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        staker.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(spender);
        staker.transferFrom(owner, spender, amount);
    }

    function testFailInvalidBalance(
        uint256 ownerPrivateKey,
        uint256 spenderPrivateKey,
        uint256 amount,
        uint256 deadline
    ) public {
        address owner;
        address spender;
        (owner, spender, ownerPrivateKey, spenderPrivateKey) = _getAddresses(ownerPrivateKey, spenderPrivateKey);

        deadline = bound(deadline, 1, 1000 days);
        amount = bound(amount, 0, type(uint256).max - 1);
        deal(address(staker), address(owner), amount);

        Permit memory permit = Permit({ owner: owner, spender: spender, value: amount, nonce: 0, deadline: 1 days });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        staker.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(spender);
        staker.transferFrom(owner, spender, amount + 1);
    }

    // ================================== SUCCESS ==================================

    function testPermitSuccess(
        uint256 ownerPrivateKey,
        uint256 spenderPrivateKey,
        uint256 amount,
        uint256 deadline
    ) public {
        address owner;
        address spender;
        (owner, spender, ownerPrivateKey, spenderPrivateKey) = _getAddresses(ownerPrivateKey, spenderPrivateKey);

        deadline = bound(deadline, 1, 1000 days);
        amount = bound(amount, 1, type(uint256).max);
        deal(address(staker), address(owner), amount);

        Permit memory permit = Permit({ owner: owner, spender: spender, value: amount, nonce: 0, deadline: deadline });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        staker.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        assertEq(staker.allowance(owner, spender), amount);
        assertEq(staker.nonces(owner), 1);
    }

    function testTransferFromLimitedPermit(
        uint256 ownerPrivateKey,
        uint256 spenderPrivateKey,
        uint256 amount,
        uint256 deadline
    ) public {
        address owner;
        address spender;
        (owner, spender, ownerPrivateKey, spenderPrivateKey) = _getAddresses(ownerPrivateKey, spenderPrivateKey);

        deadline = bound(deadline, 1, 1000 days);
        amount = bound(amount, 1, type(uint256).max / 2);
        deal(address(staker), address(owner), amount);

        Permit memory permit = Permit({ owner: owner, spender: spender, value: amount, nonce: 0, deadline: deadline });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        staker.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(spender);
        staker.transferFrom(owner, spender, amount);

        assertEq(staker.balanceOf(owner), 0);
        assertEq(staker.balanceOf(spender), amount);
        assertEq(staker.allowance(owner, spender), 0);
    }

    function testTransferFromMaxPermit(
        uint256 ownerPrivateKey,
        uint256 spenderPrivateKey,
        uint256 amount,
        uint256 deadline
    ) public {
        address owner;
        address spender;
        (owner, spender, ownerPrivateKey, spenderPrivateKey) = _getAddresses(ownerPrivateKey, spenderPrivateKey);

        deadline = bound(deadline, 1, 1000 days);
        amount = bound(amount, 1, type(uint256).max);
        deal(address(staker), address(owner), amount);

        Permit memory permit = Permit({
            owner: owner,
            spender: spender,
            value: type(uint256).max,
            nonce: 0,
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        staker.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(spender);
        staker.transferFrom(owner, spender, amount);

        assertEq(staker.balanceOf(owner), 0);
        assertEq(staker.balanceOf(spender), amount);
        assertEq(staker.allowance(owner, spender), type(uint256).max);
    }

    // ================================== HELPERS ==================================

    function _getAddresses(uint256 ownerPrivateKey, uint256 spenderPrivateKey)
        internal
        view
        returns (
            address owner,
            address spender,
            uint256,
            uint256
        )
    {
        ownerPrivateKey = bound(
            ownerPrivateKey,
            1,
            11579208923731619542357098500868790785283756427907490438260516314151816149433
        );
        spenderPrivateKey = bound(
            spenderPrivateKey,
            1,
            11579208923731619542357098500868790785283756427907490438260516314151816149433
        );

        owner = vm.addr(ownerPrivateKey);
        spender = vm.addr(spenderPrivateKey);

        vm.assume(spender != owner && owner != address(proxyAdmin) && spender != address(proxyAdmin));

        return (owner, spender, ownerPrivateKey, spenderPrivateKey);
    }
}
