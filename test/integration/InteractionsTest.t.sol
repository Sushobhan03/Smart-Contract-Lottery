// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {Lottery} from "../../src/Lottery.sol";

contract InteractionsTest is Test {
    HelperConfig helperConfig;
    CreateSubscription createSubscription;
    //FundSubscription fundSubscription;

    event mySubscriptionFUnded(uint64 indexed subId);

    address vrfCoordinatorAddress;
    uint64 subId;
    uint256 deployerKey;
    address link;

    address public PLAYER = makeAddr("player");
    uint96 public constant STARTING_USER_BALANCE = 100 ether;

    function setUp() external {
        DeployLottery deployLottery = new DeployLottery();
        (, helperConfig) = deployLottery.run();
        (, , vrfCoordinatorAddress, , subId, , link, deployerKey) = helperConfig
            .activeNetworkConfig();

        createSubscription = new CreateSubscription();
        //fundSubscription = new FundSubscription();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    modifier generateSubId() {
        subId = createSubscription.createSubscription(
            vrfCoordinatorAddress,
            deployerKey
        );
        _;
    }

    function testCreateSubscriptionCreatesANewSubId() public generateSubId {
        assert(subId > 0);
    }

    // function testFundSubscriptionEmitsEventAfterFunding() public generateSubId {
    //     vm.prank(PLAYER);
    //     vm.expectEmit();
    //     emit mySubscriptionFUnded(subId);
    //     fundSubscription.fundSubscription(
    //         vrfCoordinatorAddress,
    //         subId,
    //         link,
    //         deployerKey
    //     );
    // }

    // function testAddConsumerEmitsEventAfterConsumerIsAdded()
    //     public
    //     generateSubId
    // {
    //     vm.prank(PLAYER);
    //     vm.expectEmit(true, false, false, false, address(addConsumer));
    //     emit NewConsumerAdded(subId);
    //     addConsumer.addConsumer(
    //         address(lottery),
    //         vrfCoordinatorAddress,
    //         subId,
    //         deployerKey
    //     );
    // }
}
