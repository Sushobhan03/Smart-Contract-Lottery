//SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
//import {VRFCoordinatorV2Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

//import {VRFConsumerBaseV2} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title Smart Contract Lottery
 * @author Sushobhan Pathare
 * @notice Creates a decentralized sample lottery game
 * @dev Implements Chainlink VRFv2
 */
contract Lottery is VRFConsumerBaseV2 {
    /**
     * Errors
     */
    error Lottery__NotEnoughETHSent();
    error Lottery__TransferFailed();
    error Lottery__LotteryNotOpen();
    error Lottery__UpkeepNotNeeded(uint256 lotteryState, uint256 balance, uint256 NumberOfPLayers);

    /**
     * Type Declarations
     */
    enum LotteryState {
        OPEN,
        CALCULATING
    }
    /**
     * State Variables
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    /**
     * @dev The amount of ETH required for a participant to enter the lottery
     */
    uint256 private immutable i_entranceFee;
    /**
     * @dev The duration of a single lottery draw
     */
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callBackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    LotteryState private s_lotteryState;

    /**
     * Events
     */
    event EnteredLottery(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedLotteryWinner(uint256 indexed requestId);

    /// @notice Initializes a number of variables required for the Chainlink VRF to function
    /// @param entranceFee The minimum fee required to enter the lottery by a participant
    /// @param interval The duration of a single lottery draw
    /// @param vrfCoordinatorAddress The address of the Chainlink VRF Coordinator
    /// @param gasLane Sets the max gas price limit
    /// @param subscriptionId ID of the Chainlink Subscription
    /// @param callBackGasLimit Sets the max gas limit for FullfillRandomWords
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinatorAddress,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callBackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorAddress) {
        i_entranceFee = entranceFee;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callBackGasLimit;
        s_lotteryState = LotteryState.OPEN;
    }

    /// @notice Participants enter the lottery
    function enterLottery() external payable {
        if (msg.value < i_entranceFee) {
            revert Lottery__NotEnoughETHSent();
        }
        if (s_lotteryState != LotteryState.OPEN) {
            revert Lottery__LotteryNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit EnteredLottery(msg.sender);
    }

    /**
     * @dev This function gets called by the Chainlink Automation nodes to see if it's time to perform an upkeep.
     * The following needs to be true for this funtion to return true:
     * 1. The time interval has passed between lottery runs
     * 2. The lottery is in an OPEN state
     * 3. The contract has ETH (i.e. participants)
     * 4. (Implicit) The subscription has been funded with ETH
     *
     *
     */
    /// @return upkeepNeeded Indicates if enough time has passed for the performUpkeep function to be called
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool lotteryIsOpen = s_lotteryState == LotteryState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = (timeHasPassed && lotteryIsOpen && hasBalance && hasPlayers);

        return (upkeepNeeded, "0x0");
    }

    /// @notice Sends the request to the Chainlink VRF Coordinator to fetch the given number of Random numbers
    function performUpkeep(
        bytes calldata /* performData */
    )
        external
    {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery__UpkeepNotNeeded(uint256(s_lotteryState), address(this).balance, s_players.length);
        }
        s_lotteryState = LotteryState.CALCULATING;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callBackGasLimit, NUM_WORDS
        );
        emit RequestedLotteryWinner(requestId);
    }

    /// @notice Picks the Winner after receiving the Random Numbers from the Chainlink node
    function fulfillRandomWords(
        uint256,
        /* requestId */
        uint256[] memory randomWords
    )
        internal
        override
    {
        //Checks
        //Effects

        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_lotteryState = LotteryState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit PickedWinner(winner);
        // Interactions
        (bool isSuccess,) = winner.call{value: address(this).balance}("");
        if (!isSuccess) {
            revert Lottery__TransferFailed();
        }
    }

    //View and Pure functions

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getLotteryState() external view returns (LotteryState) {
        return s_lotteryState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLatestTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getNumPlayers() external view returns (uint256) {
        return s_players.length;
    }

    function getVrfCoordinator() external view returns (VRFCoordinatorV2Interface) {
        return i_vrfCoordinator;
    }

    function getInterval() external view returns (uint256) {
        return i_interval;
    }

    function getGasLane() external view returns (bytes32) {
        return i_gasLane;
    }

    function getSubscriptionId() external view returns (uint64) {
        return i_subscriptionId;
    }

    function getCallbackGasLimit() external view returns (uint32) {
        return i_callBackGasLimit;
    }
}
