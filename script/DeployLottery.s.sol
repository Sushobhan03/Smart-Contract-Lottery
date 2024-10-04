// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Lottery} from "../src/Lottery.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployLottery is Script {
    function run() external returns (Lottery, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinatorAddress,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            // Create subscription programatically
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(
                vrfCoordinatorAddress,
                deployerKey
            );

            // Fund it!
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinatorAddress,
                subscriptionId,
                link,
                deployerKey
            );
        }

        vm.startBroadcast(deployerKey);
        Lottery lottery = new Lottery(
            entranceFee,
            interval,
            vrfCoordinatorAddress,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        //Add Consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(lottery),
            vrfCoordinatorAddress,
            subscriptionId,
            deployerKey
        );

        return (lottery, helperConfig);
    }
}
