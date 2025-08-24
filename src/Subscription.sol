// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Subscription Manager with Monthly Payments
/// @notice Users must pay periodically (e.g., monthly) to keep their subscription active.
contract Subscription is ReentrancyGuard {
    address public immutable owner;
    uint256 public subscriptionPrice; // Price per period (wei)
    uint256 public subscriptionDuration; // Duration per period (seconds) – e.g., 30 days

    mapping(address => uint256) public subscriptions; // expiry timestamps

    event Subscribed(address indexed user, uint256 expiry);
    event Cancelled(address indexed user, uint256 refund);
    event PriceUpdated(uint256 newPrice);
    event DurationUpdated(uint256 newDuration);
    event Withdrawn(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this");
        _;
    }

    constructor(uint256 _price, uint256 _duration) {
        owner = msg.sender;
        subscriptionPrice = _price;
        subscriptionDuration = _duration; // for monthly, set to 30 days
    }

    /// @notice Pay for one or more subscription periods (months)
    /// @param periods Number of periods (e.g., months) to pay
    function subscribe(uint256 periods) external payable {
        require(periods > 0, "Must subscribe at least 1 period");
        uint256 totalPrice;
        unchecked {
            totalPrice = subscriptionPrice * periods;
        }
        require(msg.value == totalPrice, "Incorrect payment");

        uint256 currentExpiry = subscriptions[msg.sender];
        uint256 startTime = block.timestamp;
        if (currentExpiry > startTime) {
            // extend from current expiry
            subscriptions[msg.sender] = currentExpiry + subscriptionDuration * periods;
        } else {
            // start fresh from now
            unchecked {
                subscriptions[msg.sender] = startTime + subscriptionDuration * periods;
            }
        }

        emit Subscribed(msg.sender, subscriptions[msg.sender]);
    }

    /// @notice Check if an address is currently subscribed
    function isSubscribed(address user) external view returns (bool) {
        return subscriptions[user] > block.timestamp;
    }

    /// @notice Cancel subscription and refund unused time (optional feature)
    function cancelSubscription() external nonReentrant {
        uint256 expiry = subscriptions[msg.sender];
        require(expiry > block.timestamp, "No active subscription");

        // Calculate remaining time
        uint256 remainingTime = expiry - block.timestamp;

        // Refund proportional to unused time for one period
        uint256 refund;
        unchecked {
            refund = (subscriptionPrice * remainingTime) / subscriptionDuration;
        }

        subscriptions[msg.sender] = block.timestamp; // reset subscription
        (bool success,) = msg.sender.call{value: refund}("");
        require(success, "Refund failed");

        emit Cancelled(msg.sender, refund);
    }

    /// @notice Owner withdraws collected funds
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds");
        (bool success,) = owner.call{value: balance}("");
        require(success, "Withdraw failed");
        emit Withdrawn(owner, balance);
    }

    /// @notice Update subscription price
    function updatePrice(uint256 _price) external onlyOwner {
        subscriptionPrice = _price;
        emit PriceUpdated(_price);
    }

    /// @notice Update subscription duration (e.g., monthly = 30 days)
    function updateDuration(uint256 _duration) external onlyOwner {
        subscriptionDuration = _duration;
        emit DurationUpdated(_duration);
    }
}
