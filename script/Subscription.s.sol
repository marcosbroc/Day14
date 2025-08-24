// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Subscription} from "../src/Subscription.sol";

contract SubscriptionScript is Script {
    Subscription public subscription;
    uint256 immutable PRICE_WEI = vm.envUint("PRICE_WEI");
    uint256 immutable DURATION_SECONDS = vm.envUint("DURATION_SECONDS");

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        subscription = new Subscription(PRICE_WEI, DURATION_SECONDS);

        vm.stopBroadcast();
    }
}
