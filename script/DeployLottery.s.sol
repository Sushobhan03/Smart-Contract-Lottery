// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer, RegisterUpkeep} from "./Interactions.s.sol";

contract DeployLottery is Script {
    function run() external returns (Lottery, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinatorAddress,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callBackGasLimit,
            address link,
            address automationRegistrar,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        //Checks if Subscription has already been created
        if (subscriptionId == 0) {
            //Creates Subscription
            CreateSubscription createSubsciption = new CreateSubscription();
            subscriptionId = createSubsciption.createSubscription(vrfCoordinatorAddress, deployerKey);

            //Funds Subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(vrfCoordinatorAddress, subscriptionId, link, deployerKey);
        }

        //Deploys Lottery contract
        vm.startBroadcast(deployerKey);
        Lottery lottery =
            new Lottery(entranceFee, interval, vrfCoordinatorAddress, gasLane, subscriptionId, callBackGasLimit);
        vm.stopBroadcast();

        //Adds Consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(lottery), vrfCoordinatorAddress, subscriptionId, deployerKey);

        if (block.chainid != 31337) {
            //Registers new upkeep
            RegisterUpkeep registerUpkeep = new RegisterUpkeep();
            registerUpkeep.registerUpkeep(address(lottery), callBackGasLimit, link, automationRegistrar, deployerKey);
        }

        return (lottery, helperConfig);
    }
}
