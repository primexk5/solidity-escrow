// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Escrow.sol";

contract EscrowLifecycleTest is Test {
    Escrow public escrow;
    address public platform;
    address public buyer;
    address public seller;
    address public unauthorizedUser;

    uint256 public constant PLATFORM_FEE = 200;
    uint256 public constant DEAL_AMOUNT = 1 ether;
    uint256 public constant EXPECTED_PLATFORM_FEE = (DEAL_AMOUNT * PLATFORM_FEE) / 10000;
    uint256 public constant EXPECTED_SELLER_AMOUNT = DEAL_AMOUNT - EXPECTED_PLATFORM_FEE;

    event Deposited(uint256 indexed dealId, address indexed buyer, uint256 amount);
    event Released(uint256 indexed dealId, address indexed seller, uint256 sellerAmount, uint256 platformFee);
    event Refunded(uint256 indexed dealId, address indexed buyer, uint256 amount);

    function setUp() public {
        platform = address(0x1);
        buyer = address(0x2);
        seller = address(0x3);
        unauthorizedUser = address(0x4);

        vm.prank(platform);
        escrow = new Escrow(platform, PLATFORM_FEE);
    }

    function testDeposit() public {
        vm.prank(buyer);
        uint256 dealId = escrow.createDeal(seller, DEAL_AMOUNT);

        vm.expectEmit(true, true, true, true);
        emit Deposited(dealId, buyer, DEAL_AMOUNT);

        vm.prank(buyer);
        vm.deal(buyer, DEAL_AMOUNT);
        escrow.deposit{value: DEAL_AMOUNT}(dealId);

        assertEq(uint256(escrow.getDealStatus(dealId)), uint256(Escrow.Status.FUNDED));
    }

    function testConfirmDelivery() public {
        vm.prank(buyer);
        uint256 dealId = escrow.createDeal(seller, DEAL_AMOUNT);

        vm.prank(buyer);
        vm.deal(buyer, DEAL_AMOUNT);
        escrow.deposit{value: DEAL_AMOUNT}(dealId);

        uint256 initialSellerBalance = seller.balance;
        uint256 initialPlatformBalance = escrow.platformBalance();

        vm.expectEmit(true, true, true, true);
        emit Released(dealId, seller, EXPECTED_SELLER_AMOUNT, EXPECTED_PLATFORM_FEE);

        vm.prank(buyer);
        escrow.confirmDelivery(dealId);

        assertEq(uint256(escrow.getDealStatus(dealId)), uint256(Escrow.Status.COMPLETE));
        assertEq(seller.balance, initialSellerBalance + EXPECTED_SELLER_AMOUNT);
        assertEq(escrow.platformBalance(), initialPlatformBalance + EXPECTED_PLATFORM_FEE);
    }

    function testRefund() public {
        vm.prank(buyer);
        uint256 dealId = escrow.createDeal(seller, DEAL_AMOUNT);

        vm.prank(buyer);
        vm.deal(buyer, DEAL_AMOUNT);
        uint256 initialBuyerBalance = buyer.balance;

        escrow.deposit{value: DEAL_AMOUNT}(dealId);

        vm.expectEmit(true, true, true, true);
        emit Refunded(dealId, buyer, DEAL_AMOUNT);

        vm.prank(buyer);
        escrow.refund(dealId);

        assertEq(uint256(escrow.getDealStatus(dealId)), uint256(Escrow.Status.REFUNDED));
        assertEq(buyer.balance, initialBuyerBalance);
    }

    function testWithdrawPlatformFees() public {
        vm.prank(buyer);
        uint256 dealId = escrow.createDeal(seller, DEAL_AMOUNT);

        vm.prank(buyer);
        vm.deal(buyer, DEAL_AMOUNT);
        escrow.deposit{value: DEAL_AMOUNT}(dealId);

        vm.prank(buyer);
        escrow.confirmDelivery(dealId);

        uint256 initialPlatformBalance = platform.balance;
        uint256 expectedWithdrawal = escrow.platformBalance();

        vm.prank(platform);
        escrow.withdrawPlatformFees();

        assertEq(platform.balance, initialPlatformBalance + expectedWithdrawal);
        assertEq(escrow.platformBalance(), 0);
    }

    function testUnauthorizedActions() public {
        vm.prank(buyer);
        uint256 dealId = escrow.createDeal(seller, DEAL_AMOUNT);

        vm.prank(unauthorizedUser);
        vm.deal(unauthorizedUser, DEAL_AMOUNT);
        vm.expectRevert();
        escrow.deposit{value: DEAL_AMOUNT}(dealId);

        vm.prank(buyer);
        vm.deal(buyer, DEAL_AMOUNT);
        escrow.deposit{value: DEAL_AMOUNT}(dealId);

        vm.prank(unauthorizedUser);
        vm.expectRevert();
        escrow.confirmDelivery(dealId);

        vm.prank(unauthorizedUser);
        vm.expectRevert();
        escrow.refund(dealId);

        vm.prank(unauthorizedUser);
        vm.expectRevert();
        escrow.withdrawPlatformFees();
    }

    function testInvalidTransitions() public {
        vm.prank(buyer);
        uint256 dealId = escrow.createDeal(seller, DEAL_AMOUNT);

        vm.prank(buyer);
        vm.expectRevert();
        escrow.confirmDelivery(dealId);

        vm.prank(buyer);
        vm.expectRevert();
        escrow.refund(dealId);

        vm.prank(buyer);
        vm.deal(buyer, DEAL_AMOUNT);
        escrow.deposit{value: DEAL_AMOUNT}(dealId);

        vm.prank(buyer);
        escrow.confirmDelivery(dealId);

        vm.prank(buyer);
        vm.expectRevert();
        escrow.refund(dealId);

        vm.prank(buyer);
        vm.expectRevert();
        escrow.confirmDelivery(dealId);
    }

    function testEdgeCases() public {
        vm.prank(buyer);
        vm.expectRevert();
        escrow.createDeal(address(0), DEAL_AMOUNT);

        vm.prank(buyer);
        vm.expectRevert();
        escrow.createDeal(buyer, DEAL_AMOUNT);

        vm.prank(buyer);
        vm.expectRevert();
        escrow.createDeal(seller, 0);

        vm.prank(buyer);
        uint256 dealId = escrow.createDeal(seller, DEAL_AMOUNT);

        vm.prank(buyer);
        vm.deal(buyer, DEAL_AMOUNT);
        vm.expectRevert();
        escrow.deposit{value: DEAL_AMOUNT - 1}(dealId);

        vm.prank(platform);
        vm.expectRevert();
        escrow.withdrawPlatformFees();
    }

    function testUpdatePlatformFee() public {
        uint256 newFee = 300;

        vm.prank(platform);
        escrow.updatePlatformFee(newFee);

        assertEq(escrow.platformFee(), newFee);

        vm.prank(unauthorizedUser);
        vm.expectRevert();
        escrow.updatePlatformFee(400);

        vm.prank(platform);
        vm.expectRevert();
        escrow.updatePlatformFee(10000);
    }

    function testFullEscrowLifecycle() public {
        vm.prank(buyer);
        uint256 dealId = escrow.createDeal(seller, DEAL_AMOUNT);

        assertEq(uint256(escrow.getDealStatus(dealId)), uint256(Escrow.Status.AWAITING_PAYMENT));

        vm.prank(buyer);
        vm.deal(buyer, DEAL_AMOUNT);
        escrow.deposit{value: DEAL_AMOUNT}(dealId);

        assertEq(uint256(escrow.getDealStatus(dealId)), uint256(Escrow.Status.FUNDED));

        vm.prank(buyer);
        escrow.confirmDelivery(dealId);

        assertEq(uint256(escrow.getDealStatus(dealId)), uint256(Escrow.Status.COMPLETE));

        vm.prank(platform);
        escrow.withdrawPlatformFees();

        assertEq(escrow.platformBalance(), 0);
    }

    function testMultipleDeals() public {
        vm.prank(buyer);
        uint256 deal1 = escrow.createDeal(seller, DEAL_AMOUNT);

        address buyer2 = address(0x5);
        vm.deal(buyer2, DEAL_AMOUNT);
        vm.prank(buyer2);
        uint256 deal2 = escrow.createDeal(seller, DEAL_AMOUNT);

        assertEq(deal1, 0);
        assertEq(deal2, 1);
        assertEq(escrow.dealCounter(), 2);

        vm.prank(buyer);
        vm.deal(buyer, DEAL_AMOUNT);
        escrow.deposit{value: DEAL_AMOUNT}(deal1);

        vm.prank(buyer2);
        escrow.deposit{value: DEAL_AMOUNT}(deal2);

        vm.prank(buyer);
        escrow.confirmDelivery(deal1);

        vm.prank(buyer2);
        escrow.refund(deal2);

        assertEq(uint256(escrow.getDealStatus(deal1)), uint256(Escrow.Status.COMPLETE));
        assertEq(uint256(escrow.getDealStatus(deal2)), uint256(Escrow.Status.REFUNDED));
        assertEq(escrow.platformBalance(), EXPECTED_PLATFORM_FEE);
    }
}
