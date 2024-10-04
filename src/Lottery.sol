// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts@1.2.0/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {console} from "forge-std/console.sol";

/**
 * @title A decentralized lottery system
 * @author Sushobhan Pathare
 * @notice This contract is for creating a decentralized lottery game
 * @dev Implements Chainlink VRFv2 and Chainlink Keepers
 */
contract Lottery is VRFConsumerBaseV2 {
    /** Errors */
    error Lottery__NotEnoughETHSent();
    error Lottery__TransferFailed();
    error Lottery__LotteryNotOpen();
    error Lottery__UpkeepNotNeeded(
        uint256 numPlayers,
        uint256 balance,
        uint256 lotteryState
    );

    /** Type Declarations */
    enum LotteryState {
        OPEN, //0
        CALCULATING //1
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    // @dev Duration between two lottery draws
    uint256 private s_lastTimestamp;
    address private s_recentWinner;
    LotteryState private s_lotteryState;

    /** Events */
    event LotteryEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRandomWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinatorAddress,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorAddress) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimestamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lotteryState = LotteryState.OPEN;
    }

    function enterLottery() external payable {
        if (msg.value < i_entranceFee) {
            revert Lottery__NotEnoughETHSent();
        }
        if (s_lotteryState != LotteryState.OPEN) {
            revert Lottery__LotteryNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit LotteryEntered(msg.sender);
    }

    /**
     * @dev This is the function which the Chainlink Automation nodes call
     * to see if it is time to perform an upkeep.
     * The following should be true for this function to return true:
     * 1. Enough time has passed between two lottery draws.
     * 2. The lottery is in an OPEN state.
     * 3. The lottery has participants who have deposited their entrance fees into the
     * lottery
     * 4. (Implicit) The Subscription has been funded with LINK
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimestamp) >= i_interval;
        bool hasPlayers = (s_players.length > 0);
        bool isOpen = (s_lotteryState == LotteryState.OPEN);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded = (timeHasPassed && hasPlayers && isOpen && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery__UpkeepNotNeeded(
                s_players.length,
                address(this).balance,
                uint256(s_lotteryState)
            );
        }
        s_lotteryState = LotteryState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRandomWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        // Checks
        // Effects (our own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_lotteryState = LotteryState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);
        // Interactions (Other contracts)
        (bool isSuccess, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!isSuccess) {
            revert Lottery__TransferFailed();
        }
    }

    /** Getter Functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getGasLane() public view returns (bytes32) {
        return i_gasLane;
    }

    function getSubscriptionId() public view returns (uint64) {
        return i_subscriptionId;
    }

    function getNumberOfRequestConfirmations() public pure returns (uint16) {
        return REQUEST_CONFIRMATIONS;
    }

    function getCallbackGasLimit() public view returns (uint32) {
        return i_callbackGasLimit;
    }

    function getNumWords() public pure returns (uint32) {
        return NUM_WORDS;
    }

    function getLastTimestamp() public view returns (uint256) {
        return s_lastTimestamp;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getCurrentLotteryState() public view returns (LotteryState) {
        return s_lotteryState;
    }

    function getPlayer(uint256 indexOfPlayer) public view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getNumPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getVrfCoordinator()
        public
        view
        returns (VRFCoordinatorV2Interface)
    {
        return i_vrfCoordinator;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
