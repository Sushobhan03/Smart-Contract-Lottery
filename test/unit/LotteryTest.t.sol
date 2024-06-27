// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Lottery} from "../../src/Lottery.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

//import {Test, console} from "../../lib/forge-std/src/Test.sol";

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract LotteryTest is Test {
    HelperConfig helperConfig;
    Lottery lottery;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinatorAddress;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callBackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint96 public constant STARTING_USER_BALANCE = 100 ether;

    event EnteredLottery(address indexed player);
    event PickedWinner(address indexed winner);

    function setUp() external {
        DeployLottery deployer = new DeployLottery();
        (lottery, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinatorAddress,
            gasLane,
            subscriptionId,
            callBackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    /////////////////////////////////
    ///// constructor ///////////////
    /////////////////////////////////

    /////////////////////////////////
    ///// enterLottery //////////////
    /////////////////////////////////

    function testLotteryRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Lottery.Lottery__NotEnoughETHSent.selector);
        lottery.enterLottery();
    }

    function testLotteryRecordsPlayerEntry() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        address tempPlayer = lottery.getPlayer(0);
        assertEq(tempPlayer, PLAYER);
    }

    function testEventIsEmittedOnPlayerEntry() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(lottery));
        emit EnteredLottery(PLAYER);
        lottery.enterLottery{value: entranceFee}();
    }

    function testCantEnterWhenLotteryIsCalculating()
        public
        enteredLotteryAndTimePassed
    {
        lottery.performUpkeep("");

        vm.prank(PLAYER);
        vm.expectRevert(Lottery.Lottery__LotteryNotOpen.selector);
        lottery.enterLottery{value: entranceFee}();
    }

    /////////////////////////////////
    ///// checkUpKeep ///////////////
    /////////////////////////////////

    function testCheckUpkeepReturnsFalseIfEnoughTimeNotPassed() public {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfLotteryNotOpen()
        public
        enteredLotteryAndTimePassed
    {
        lottery.performUpkeep("");

        (bool upkeepNeeded, ) = lottery.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfLotteryHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = lottery.checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsTrueIfAllParametersAreGood()
        public
        enteredLotteryAndTimePassed
    {
        (bool upkeepNeeded, ) = lottery.checkUpkeep((""));

        assert(upkeepNeeded == true);
    }

    /////////////////////////////////
    ///// performUpkeep /////////////
    /////////////////////////////////

    function testPerformUpkeepRunsOnlyIfCheckUpkeepReturnsTrue()
        public
        enteredLotteryAndTimePassed
    {
        lottery.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepReturnsFalse() public {
        uint256 balance = 0;
        uint256 numPlayers = 0;
        uint256 lotteryState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__UpkeepNotNeeded.selector,
                lotteryState,
                balance,
                numPlayers
            )
        );
        lottery.performUpkeep("");
    }

    modifier enteredLotteryAndTimePassed() {
        vm.prank(PLAYER);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesLotteryStateAndEmitsRequestId()
        public
        enteredLotteryAndTimePassed
    {
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Lottery.LotteryState lState = lottery.getLotteryState();

        assert(uint256(lState) == 1);

        assert(uint256(requestId) > 0);
    }

    /////////////////////////////////
    ///// fulfillRandomWords ////////
    /////////////////////////////////

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public enteredLotteryAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinatorAddress).fulfillRandomWords(
            randomRequestId,
            address(lottery)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        enteredLotteryAndTimePassed
        skipFork
    {
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            lottery.enterLottery{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        //kickoff a chainlink request
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = lottery.getLatestTimeStamp();

        //Manually call the chainlink VRF to generate the ranadom number
        VRFCoordinatorV2Mock(vrfCoordinatorAddress).fulfillRandomWords(
            uint256(requestId),
            address(lottery)
        );

        assert(uint256(lottery.getLotteryState()) == 0);
        assert(lottery.getRecentWinner() != address(0));
        assert(lottery.getNumPlayers() == 0);
        assert(previousTimeStamp < lottery.getLatestTimeStamp());
        assert(
            lottery.getRecentWinner().balance ==
                STARTING_USER_BALANCE + prize - entranceFee
        );
    }

    function testFulfillRandomWordsEmitsEventAfterWInnerGetsPicked()
        public
        enteredLotteryAndTimePassed
        skipFork
    {
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(lottery));
        emit PickedWinner(PLAYER);
        VRFCoordinatorV2Mock(vrfCoordinatorAddress).fulfillRandomWords(
            uint256(requestId),
            address(lottery)
        );
    }

    /////////////////////////////////
    // View and Pure functions //////
    /////////////////////////////////

    function testIfTheConstructorSetsAllTheVariablesCorrectly() public view {
        assert(lottery.getEntranceFee() == entranceFee);
        assert(
            lottery.getVrfCoordinator() ==
                VRFCoordinatorV2Interface(vrfCoordinatorAddress)
        );
        assert(lottery.getInterval() == interval);
        assert(lottery.getGasLane() == gasLane);
        assert(lottery.getCallbackGasLimit() == callBackGasLimit);
        assert(lottery.getLotteryState() == Lottery.LotteryState.OPEN);
    }
}
