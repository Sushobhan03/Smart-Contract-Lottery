// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts@1.2.0/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinatorAddress,
            ,
            ,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinatorAddress, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating Subscription on ChainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subId is ", subId);
        console.log("Please add it to your HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinatorAddress,
            ,
            uint64 subscriptionId,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(
            vrfCoordinatorAddress,
            subscriptionId,
            link,
            deployerKey
        );
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address link,
        uint256 deployerKey
    ) public {
        console.log("Funding Subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        return fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address lottery,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer contracts: ", lottery);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, lottery);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address lottery) public {
        HelperConfig helperConfig = new HelperConfig();

        (
            ,
            ,
            address vrfCoordinatorAddress,
            ,
            uint64 subscriptionId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        addConsumer(
            lottery,
            vrfCoordinatorAddress,
            subscriptionId,
            deployerKey
        );
    }

    function run() external {
        address lottery = DevOpsTools.get_most_recent_deployment(
            "Lottery",
            block.chainid
        );

        addConsumerUsingConfig(lottery);
    }
}
