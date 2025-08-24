// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Subscription} from "../src/Subscription.sol";

contract SubscriptionTest is Test {
    Subscription public subscription;
    uint256 immutable PRICE_WEI = vm.envUint("PRICE_WEI");
    uint256 immutable DURATION_SECONDS = vm.envUint("DURATION_SECONDS");
    address immutable SUBSCRIBER_1 = vm.envAddress("ACCOUNT_1");
    address immutable SUBSCRIBER_2 = vm.envAddress("ACCOUNT_2");
    address immutable SUBSCRIBER_3 = vm.envAddress("ACCOUNT_3");
    uint256 public subscriptionPeriods;
    address owner;

    // We specify the price in wei for 1 subscription period (defined in seconds)
    function setUp() public {
        subscription = new Subscription(PRICE_WEI, DURATION_SECONDS);
        owner = address(this);
        vm.deal(SUBSCRIBER_1, 1 ether);
        vm.deal(SUBSCRIBER_2, 2 ether);
        vm.deal(SUBSCRIBER_3, 90 ether);
    }

    function test_subscribe() public {
        // Successful subscription 12 months (12 periods of 30 days)
        subscriptionPeriods = 12;
        uint256 subscriptionCost = subscriptionPeriods * PRICE_WEI;
        vm.prank(SUBSCRIBER_1);
        subscription.subscribe{value: subscriptionCost}(subscriptionPeriods);

        // Not paying enough money to subscribe for 6 months
        subscriptionPeriods = 6;
        subscriptionCost = subscriptionPeriods * PRICE_WEI;
        vm.prank(SUBSCRIBER_2);
        vm.expectRevert("Incorrect payment");
        subscription.subscribe{value: subscriptionCost - 1}(subscriptionPeriods);
    }

    function test_fuzzSubscribe(address x, uint8 y) public {
        // Subscription must be at least 1 month but maximum 10 years
        vm.assume(y > 0);
        vm.assume(y <= 120);

        // Successful subscription
        subscriptionPeriods = y;
        uint256 subscriptionCost = subscriptionPeriods * PRICE_WEI;
        vm.deal(x, 100 ether);
        vm.prank(x);
        subscription.subscribe{value: subscriptionCost}(subscriptionPeriods);
    }

    function test_isSubscribed() public {
        // Successful subscription 12 months (12 periods of 30 days)
        subscriptionPeriods = 12;
        uint256 subscriptionCost = subscriptionPeriods * PRICE_WEI;
        vm.prank(SUBSCRIBER_1);
        subscription.subscribe{value: subscriptionCost}(subscriptionPeriods);

        console.log("Subscriber 1 subscribed:", subscription.isSubscribed(SUBSCRIBER_1));
        console.log("Subscriber 2 subscribed:", subscription.isSubscribed(SUBSCRIBER_2));

        // Fast forward in time, the subscriber 1 is not subscribed anymore
        uint256 monthSeconds = 2592000;
        vm.warp(block.timestamp + monthSeconds * 12);
        console.log("12 months later, subscriber 1 subscribed:", subscription.isSubscribed(SUBSCRIBER_1));
    }

    function test_withdraw() public {
        test_subscribe();
        console.log("Previous balance of owner:", address(this).balance);
        console.log("About to call withdraw");
        vm.prank(owner);
        subscription.withdraw();
        console.log("Current balance of owner:", address(this).balance);
    }

    function test_cancelSubscription() public {
        console.log("Balance of subscriber before subscribing:", address(SUBSCRIBER_1).balance);
        test_subscribe();
        console.log("Previous balance of subscriber before cancellation:", address(SUBSCRIBER_1).balance);
        vm.prank(SUBSCRIBER_1);
        subscription.cancelSubscription();
        console.log("Current balance of subscriber after cancellation:", address(SUBSCRIBER_1).balance);
    }

    receive() external payable {}

    function testMonthlySubscription() public {
        // Simulate an externally-owned account (subscriber)
        address user = vm.addr(1);
        vm.deal(user, 10 ether); // give the user some ETH

        // Deploy subscription contract as the owner
        subscription = new Subscription(0.05 ether, 30 days);

        // User pays for 1 month
        vm.startPrank(user);
        subscription.subscribe{value: 0.05 ether}(1);
        vm.stopPrank();

        // Check if active right after payment
        bool active = subscription.isSubscribed(user);
        assertTrue(active, "User should be active after subscribing");

        // Move time forward 29 days (still active)
        vm.warp(block.timestamp + 29 days);
        active = subscription.isSubscribed(user);
        assertTrue(active, "User should still be active before expiry");

        // Move forward to 31 days (expired)
        vm.warp(block.timestamp + 2 days);
        active = subscription.isSubscribed(user);
        assertFalse(active, "User should be inactive after period ends");

        // User pays for 3 months at once
        vm.startPrank(user);
        subscription.subscribe{value: 0.15 ether}(3);
        vm.stopPrank();

        // Check that expiry is extended 3 months
        active = subscription.isSubscribed(user);
        assertTrue(active, "User should be active after paying for 3 months");
    }
}
