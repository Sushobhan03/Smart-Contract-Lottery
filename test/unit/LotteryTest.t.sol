// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Lottery} from "../../src/Lottery.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts@1.2.0/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

import {VRFCoordinatorV2Interface} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

contract LotteryTest is Test {
    Lottery lottery;
    HelperConfig helperConfig;

    address public PLAYER1 = makeAddr("player");
    address public PLAYER2 = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinatorAddress;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    // Events
    event LotteryEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployLottery deployer = new DeployLottery();
        (lottery, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinatorAddress,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER1, STARTING_USER_BALANCE);
    }

    function testLotteryInitializesInOpenState() public view {
        assert(lottery.getCurrentLotteryState() == Lottery.LotteryState.OPEN);
    }

    //////////////////////////////////////////
    ////// enterLottery //////////////////////
    //////////////////////////////////////////

    function testLotteryRevertsWhenYouDontPayEnoughEth() public {
        vm.prank(PLAYER1);
        vm.expectRevert(Lottery.Lottery__NotEnoughETHSent.selector);
        lottery.enterLottery();
    }

    function testLotteryRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER1);
        lottery.enterLottery{value: entranceFee}();
        assertEq(lottery.getPlayer(0), PLAYER1);
    }

    function testIfEventIsEmittedOnPlayerEntry() public {
        vm.prank(PLAYER1);
        vm.expectEmit(true, false, false, false, address(lottery));
        emit LotteryEntered(PLAYER1);
        lottery.enterLottery{value: entranceFee}();
    }

    function testCantEnterIfLotteryCalculating()
        public
        enteredLotteryAndTimePassed
    {
        lottery.performUpkeep("");

        vm.expectRevert(Lottery.Lottery__LotteryNotOpen.selector);
        vm.prank(PLAYER1);
        lottery.enterLottery{value: entranceFee}();
    }

    //////////////////////////////////////////
    ////// checkUpkeep ///////////////////////
    //////////////////////////////////////////

    function testCheckUpkeepReturnsFalseIfItHasNoBalanceAndNoPLayers() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = lottery.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasNotPassed() public {
        vm.prank(PLAYER1);
        lottery.enterLottery{value: entranceFee}();

        (bool upkeepNeeded, ) = lottery.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepIfLotteryIsNotOpen()
        public
        enteredLotteryAndTimePassed
    {
        lottery.performUpkeep("");

        (bool upkeepNeeded, ) = lottery.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueIfEveryParameterIsTrue()
        public
        enteredLotteryAndTimePassed
    {
        (bool upkeepNeeded, ) = lottery.checkUpkeep("");

        assert(upkeepNeeded);
    }

    modifier enteredLotteryAndTimePassed() {
        vm.prank(PLAYER1);
        lottery.enterLottery{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    //////////////////////////////////////////
    ////// performUpkeep /////////////////////
    //////////////////////////////////////////

    function testOnlyRunsIfCheckUpkeepReturnsTrue()
        public
        enteredLotteryAndTimePassed
    {
        lottery.performUpkeep("");
    }

    function testRevertsIfUpkeepNotNeeded() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 lotteryState = 0;

        vm.prank(PLAYER1);
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__UpkeepNotNeeded.selector,
                numPlayers,
                currentBalance,
                lotteryState
            )
        );

        lottery.performUpkeep("");
    }

    function testPeformUpkeepUpdatesStateAndEmitsRequestId()
        public
        enteredLotteryAndTimePassed
    {
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        Lottery.LotteryState lState = lottery.getCurrentLotteryState();

        assert(uint256(requestId) > 0);
        assert(uint256(lState) == 1);
    }

    //////////////////////////////////////////
    ////// fulfillRandomWords ////////////////
    //////////////////////////////////////////

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

    function testFulfillRandomWordsPicksWinnerResetsAndSendsMoney()
        public
        enteredLotteryAndTimePassed
        skipFork
    {
        //Arrange
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
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimestamp = lottery.getLastTimestamp();

        VRFCoordinatorV2Mock(vrfCoordinatorAddress).fulfillRandomWords(
            uint256(requestId),
            address(lottery)
        );
        uint256 balanceOfWinner = lottery.getRecentWinner().balance;
        //assert
        assertEq(uint256(lottery.getCurrentLotteryState()), 0);
        assert(lottery.getRecentWinner() != address(0));
        assert(lottery.getNumPlayers() == 0);
        assert(previousTimestamp < lottery.getLastTimestamp());
        assert(
            (balanceOfWinner == (STARTING_USER_BALANCE + prize - entranceFee))
        );
    }

    function testFulfillRandomWordsEmitsEventAfterWinnerIsPicked()
        public
        enteredLotteryAndTimePassed
        skipFork
    {
        vm.recordLogs();
        lottery.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        vm.expectEmit(true, false, false, false, address(lottery));
        emit WinnerPicked(PLAYER1);
        VRFCoordinatorV2Mock(vrfCoordinatorAddress).fulfillRandomWords(
            uint256(requestId),
            address(lottery)
        );
    }

    function testIfTheConstructorSetsAllTheVariablesCorrectly() public view {
        assert(lottery.getEntranceFee() == entranceFee);
        assert(
            lottery.getVrfCoordinator() ==
                VRFCoordinatorV2Interface(vrfCoordinatorAddress)
        );
        assert(lottery.getInterval() == interval);
        assert(lottery.getGasLane() == gasLane);
        assert(lottery.getCallbackGasLimit() == callbackGasLimit);
        assert(lottery.getCurrentLotteryState() == Lottery.LotteryState.OPEN);
    }

    //Getter functions

    function testIfGetEntranceFeeReturnsCorrectValue() public view {
        uint256 expectedEntranceFee = 0.01 ether;
        assertEq(lottery.getEntranceFee(), expectedEntranceFee);
    }

    function testIfGetGasLaneReturnsCorrectValue() public view {
        bytes32 expectedGasLane = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
        assertEq(lottery.getGasLane(), expectedGasLane);
    }

    function testIfGetNumWordsReturnsCorrectValue() public view {
        uint32 expectedNumWords = 1;
        assertEq(lottery.getNumWords(), expectedNumWords);
    }

    function testIfGetRequestConfirmationsReturnsCorrectValue() public view {
        uint16 expectedRequestConfirmations = 3;
        assertEq(
            lottery.getNumberOfRequestConfirmations(),
            expectedRequestConfirmations
        );
    }
}
