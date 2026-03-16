// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Escrow.sol";

contract EscrowTest is Test {
    Escrow public escrow;
    address public platform;
    address public buyer;
    address public seller;
    address public unauthorizedUser;

    uint256 public constant PLATFORM_FEE = 200; // 2%
    uint256 public constant DEAL_AMOUNT = 1 ether;

    event DealCreated(uint256 indexed dealId, address indexed buyer, address indexed seller, uint256 amount);

    function setUp() public {
        platform = address(0x1);
        buyer = address(0x2);
        seller = address(0x3);
        unauthorizedUser = address(0x4);

        vm.prank(platform);
        escrow = new Escrow(platform, PLATFORM_FEE);
    }

    function testConstructor() public {
        assertEq(escrow.platform(), platform);
        assertEq(escrow.platformFee(), PLATFORM_FEE);
        assertEq(escrow.dealCounter(), 0);
        assertEq(escrow.platformBalance(), 0);
    }

    function testCreateDeal() public {
        vm.prank(buyer);
        uint256 dealId = escrow.createDeal(seller, DEAL_AMOUNT);

        assertEq(dealId, 0);
        assertEq(escrow.dealCounter(), 1);

        (address dealBuyer, address dealSeller, uint256 amount, Escrow.Status status) = escrow.getDeal(dealId);
        assertEq(dealBuyer, buyer);
        assertEq(dealSeller, seller);
        assertEq(amount, DEAL_AMOUNT);
        assertEq(uint256(status), uint256(Escrow.Status.AWAITING_PAYMENT));
    }

    function testCreateDealEmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit DealCreated(0, buyer, seller, DEAL_AMOUNT);

        vm.prank(buyer);
        escrow.createDeal(seller, DEAL_AMOUNT);
    }
}
