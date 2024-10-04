// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts@1.2.0/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract InteractionsTest is Test {
    CreateSubscription createSubscription;
    FundSubscription fundSubscription;
    AddConsumer addConsumer;
    HelperConfig helperConfig;
    Lottery lottery;

    address vrfCoordinatorAddress;
    uint64 subscriptionId;
    address link;
    uint256 deployerKey;

    //Events
    event SubscriptionFunded(
        uint64 indexed subId,
        uint256 oldBalance,
        uint256 newBalance
    );
    event ConsumerAdded(uint64 indexed subId, address consumer);
    event SubscriptionConsumerAdded(uint64 indexed subId, address consumer);

    function setUp() external {
        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();
        addConsumer = new AddConsumer();

        DeployLottery deployer = new DeployLottery();
        (lottery, helperConfig) = deployer.run();

        (
            ,
            ,
            vrfCoordinatorAddress,
            ,
            subscriptionId,
            ,
            link,
            deployerKey
        ) = helperConfig.activeNetworkConfig();
    }

    modifier subscriptionCreated() {
        subscriptionId = createSubscription.createSubscription(
            vrfCoordinatorAddress,
            deployerKey
        );
        _;
    }

    function testCreateSubscriptionCreatesANewSubId()
        public
        subscriptionCreated
    {
        assert(subscriptionId > 0);
    }

    function testFundSubscriptionEmitsEventAfterFundingSubscription()
        public
        subscriptionCreated
    {
        uint256 amountToBeFunded = 3 ether;
        uint256 oldBalance = 0;

        vm.expectEmit(true, false, false, true, vrfCoordinatorAddress);
        emit SubscriptionFunded(
            subscriptionId,
            oldBalance,
            oldBalance + amountToBeFunded
        );
        fundSubscription.fundSubscription(
            vrfCoordinatorAddress,
            subscriptionId,
            link,
            deployerKey
        );
    }

    function testAddConsumerEmitsEventAfterAddingConsumer()
        public
        subscriptionCreated
    {
        address lotteryAddress = address(lottery);

        if (block.chainid == 31337) {
            vm.expectEmit(true, false, false, true, vrfCoordinatorAddress);
            emit ConsumerAdded(subscriptionId, lotteryAddress);
            addConsumer.addConsumer(
                lotteryAddress,
                vrfCoordinatorAddress,
                subscriptionId,
                deployerKey
            );
            bool isConsumerAdded = VRFCoordinatorV2Mock(vrfCoordinatorAddress)
                .consumerIsAdded(subscriptionId, lotteryAddress);
            assertTrue(isConsumerAdded, "Consumer was not added successfully");
        } else {
            vm.expectEmit(true, false, false, true, vrfCoordinatorAddress);
            emit SubscriptionConsumerAdded(subscriptionId, lotteryAddress);
            addConsumer.addConsumer(
                lotteryAddress,
                vrfCoordinatorAddress,
                subscriptionId,
                deployerKey
            );
        }
    }
}
