// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer, EnterLottery} from "../../script/Interactions.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {Lottery} from "../../src/Lottery.sol";
import {LinkToken} from "../mocks/LinkToken.sol";

contract InteractionsTest is Test {
    HelperConfig helperConfig;
    CreateSubscription createSubscription;
    FundSubscription fundSubscription;
    AddConsumer addConsumer;
    EnterLottery enterLottery;
    Lottery lottery;

    address vrfCoordinatorAddress;
    uint256 deployerKey;
    address link;
    uint256 entranceFee;

    address public PLAYER = makeAddr("player");
    uint96 public constant STARTING_USER_BALANCE = 100 ether;

    function setUp() external {
        DeployLottery deployLottery = new DeployLottery();
        (lottery, helperConfig) = deployLottery.run();
        (entranceFee,, vrfCoordinatorAddress,,,, link,, deployerKey) = helperConfig.activeNetworkConfig();

        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();
        addConsumer = new AddConsumer();
        enterLottery = new EnterLottery();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function _createSub() internal returns (uint64) {
        return createSubscription.createSubscription(vrfCoordinatorAddress, deployerKey);
    }

    function testCreateSubscriptionRegistersSubscription() public {
        uint64 subId = _createSub();
        (uint96 balance, uint64 reqCount, address owner, address[] memory consumers) =
            VRFCoordinatorV2Mock(vrfCoordinatorAddress).getSubscription(subId);
        assertEq(balance, 0);
        assertEq(reqCount, 0);
        assertEq(owner, vm.addr(deployerKey));
        assertEq(consumers.length, 0);
    }

    function testFundSubscriptionIncreasesBalance() public {
        uint64 subId = _createSub();

        (uint96 balanceBefore,,,) = VRFCoordinatorV2Mock(vrfCoordinatorAddress).getSubscription(subId);

        fundSubscription.fundSubscription(vrfCoordinatorAddress, subId, link, deployerKey);

        (uint96 balanceAfter,,,) = VRFCoordinatorV2Mock(vrfCoordinatorAddress).getSubscription(subId);

        assertEq(balanceBefore, 0);
        assertEq(balanceAfter, fundSubscription.FUND_AMOUNT());
    }

    function testFundSubscriptionRevertsIfSubDoesNotExist() public {
        vm.expectRevert();

        fundSubscription.fundSubscription(vrfCoordinatorAddress, 999, link, deployerKey);
    }

    function testAddConsumerAddsLotteryAsConsumer() public {
        uint64 subId = _createSub();

        addConsumer.addConsumer(address(lottery), vrfCoordinatorAddress, subId, deployerKey);

        (,,, address[] memory consumers) = VRFCoordinatorV2Mock(vrfCoordinatorAddress).getSubscription(subId);

        assertEq(consumers.length, 1);
        assertEq(address(consumers[0]), address(lottery));
    }

    function testAddConsumerSupportsMultipleConsumers() public {
        uint64 subId = _createSub();

        address lottery1 = makeAddr("lottery1");
        address lottery2 = makeAddr("lottery2");

        addConsumer.addConsumer(lottery1, vrfCoordinatorAddress, subId, deployerKey);

        addConsumer.addConsumer(lottery2, vrfCoordinatorAddress, subId, deployerKey);

        (,,, address[] memory consumers) = VRFCoordinatorV2Mock(vrfCoordinatorAddress).getSubscription(subId);

        assertEq(consumers.length, 2);
        assertEq(address(consumers[0]), address(lottery1));
        assertEq(address(consumers[1]), address(lottery2));
    }

    function testAddConsumerRevertsIfSubDoesNotExist() public {
        vm.expectRevert();
        addConsumer.addConsumer(address(lottery), vrfCoordinatorAddress, 999, deployerKey);
    }

    function testEnterLotteryInteraction() public {
        address player = vm.addr(deployerKey);
        vm.deal(player, 10 ether);

        enterLottery.enterLottery(address(lottery), entranceFee, deployerKey);

        address recordedPlayer = lottery.getPlayer(0);
        assertEq(recordedPlayer, player);
    }
}

