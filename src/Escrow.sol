// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Escrow is ReentrancyGuard {
    enum Status { AWAITING_PAYMENT, FUNDED, COMPLETE, REFUNDED }

    struct Deal {
        address buyer;
        address seller;
        uint256 amount;
        Status status;
    }

    address public platform;
    uint256 public platformFee;
    uint256 public dealCounter;
    mapping(uint256 => Deal) public deals;
    uint256 public platformBalance;

    event DealCreated(uint256 indexed dealId, address indexed buyer, address indexed seller, uint256 amount);
    event Deposited(uint256 indexed dealId, address indexed buyer, uint256 amount);
    event Released(uint256 indexed dealId, address indexed seller, uint256 sellerAmount, uint256 platformFee);
    event Refunded(uint256 indexed dealId, address indexed buyer, uint256 amount);

    error InvalidAddress();
    error InvalidAmount();
    error DealNotFound();
    error UnauthorizedAction();
    error InvalidStatus();
    error AlreadyDeposited();
    error InsufficientPayment();
    error TransferFailed();

    modifier onlyPlatform() {
        if (msg.sender != platform) revert UnauthorizedAction();
        _;
    }

    modifier onlyBuyer(uint256 dealId) {
        if (msg.sender != deals[dealId].buyer) revert UnauthorizedAction();
        _;
    }

    modifier dealExists(uint256 dealId) {
        if (dealId >= dealCounter) revert DealNotFound();
        _;
    }

    constructor(address _platform, uint256 _platformFee) {
        if (_platform == address(0)) revert InvalidAddress();
        if (_platformFee >= 10000) revert InvalidAmount();

        platform = _platform;
        platformFee = _platformFee;
        dealCounter = 0;
    }

    function createDeal(address seller, uint256 amount) external returns (uint256 dealId) {
        if (seller == address(0)) revert InvalidAddress();
        if (seller == msg.sender) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        dealId = dealCounter++;
        deals[dealId] = Deal({
            buyer: msg.sender,
            seller: seller,
            amount: amount,
            status: Status.AWAITING_PAYMENT
        });

        emit DealCreated(dealId, msg.sender, seller, amount);
    }

    function deposit(uint256 dealId) external payable nonReentrant dealExists(dealId) {
        Deal storage deal = deals[dealId];
        if (deal.status != Status.AWAITING_PAYMENT) revert InvalidStatus();
        if (msg.value != deal.amount) revert InsufficientPayment();
        if (msg.sender != deal.buyer) revert UnauthorizedAction();

        deal.status = Status.FUNDED;
        emit Deposited(dealId, msg.sender, msg.value);
    }

    function confirmDelivery(uint256 dealId) external nonReentrant dealExists(dealId) onlyBuyer(dealId) {
        Deal storage deal = deals[dealId];
        if (deal.status != Status.FUNDED) revert InvalidStatus();

        uint256 platformFeeAmount = (deal.amount * platformFee) / 10000;
        uint256 sellerAmount = deal.amount - platformFeeAmount;

        deal.status = Status.COMPLETE;
        platformBalance += platformFeeAmount;

        (bool success, ) = payable(deal.seller).call{value: sellerAmount}("");
        if (!success) revert TransferFailed();

        emit Released(dealId, deal.seller, sellerAmount, platformFeeAmount);
    }

    function refund(uint256 dealId) external nonReentrant dealExists(dealId) onlyBuyer(dealId) {
        Deal storage deal = deals[dealId];
        if (deal.status != Status.FUNDED) revert InvalidStatus();

        deal.status = Status.REFUNDED;

        (bool success, ) = payable(deal.buyer).call{value: deal.amount}("");
        if (!success) revert TransferFailed();

        emit Refunded(dealId, deal.buyer, deal.amount);
    }

    function withdrawPlatformFees() external nonReentrant onlyPlatform {
        uint256 amount = platformBalance;
        if (amount == 0) revert InvalidAmount();

        platformBalance = 0;

        (bool success, ) = payable(platform).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    function updatePlatformFee(uint256 _platformFee) external onlyPlatform {
        if (_platformFee >= 10000) revert InvalidAmount();
        platformFee = _platformFee;
    }

    function getDealStatus(uint256 dealId) external view dealExists(dealId) returns (Status) {
        return deals[dealId].status;
    }

    function getDeal(uint256 dealId) external view dealExists(dealId) returns (address buyer, address seller, uint256 amount, Status status) {
        Deal storage deal = deals[dealId];
        return (deal.buyer, deal.seller, deal.amount, deal.status);
    }

    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }

    fallback() external payable {
        revert("Function not found");
    }
}
