//SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {Lottery} from "../src/Lottery.sol";
import {AutomationRegistrar2_1} from "@chainlink/contracts/src/v0.8/automation/v2_1/AutomationRegistrar2_1.sol";

/// @title Creating Subscription
/// @author Sushobhan Pathare
/// @notice This contract creates a new subscription
contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinatorAddress,,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinatorAddress, deployerKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns (uint64) {
        console.log("Creating Subscription on ChainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your sub Id is: ", subId);
        console.log("Please update subscriptionId in HelperConfig.s.sol");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

/// @title Funding Subscription
/// @author Sushobhan Pathare
/// @notice This contract funds the created subscription
contract FundSubscription is Script {
    //event mySubscriptionFUnded(uint64 indexed subId);
    uint96 public constant FUND_AMOUNT = 3 ether; //Amount has to be uint96

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinatorAddress,, uint64 subId,, address link,, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinatorAddress, subId, link, deployerKey);
    }

    function fundSubscription(address vrfCoordinator, uint64 subId, address link, uint256 deployerKey) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
            //emit mySubscriptionFUnded(subId);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
            //emit mySubscriptionFUnded(subId);
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

/// @title Consumer Addition
/// @author Sushobhan Pathare
/// @notice This contract adds a new consumer contract to the created Subscription
contract AddConsumer is Script {
    function addConsumer(address lottery, address vrfCoordinator, uint64 subId, uint256 deployerKey) public {
        console.log("Adding Consumer contract: ", lottery);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, lottery);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address lottery) public {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,, uint64 subId,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        addConsumer(lottery, vrfCoordinator, subId, deployerKey);
    }

    function run() external {
        address lottery = DevOpsTools.get_most_recent_deployment("Lottery", block.chainid);
        addConsumerUsingConfig(lottery);
    }
}

/// @title Upkeep Registration
/// @author Sushobhan Pathare
/// @notice This contract registers a new Upkeep with the Chainlink Automation programmatically
/// @dev This cannot run on the Local Anvil Chain as there is no mock AutomationRegistrar2_1 availble
contract RegisterUpkeep is Script {
    uint96 constant FUND_AMOUNT = 5 ether;

    function registerUpkeepUsingConfig(address lottery) public {
        HelperConfig helperConfig = new HelperConfig();

        (,,,,, uint32 callbackGasLimit, address link, address automationRegistrar, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        registerUpkeep(lottery, callbackGasLimit, link, automationRegistrar, deployerKey);
    }

    function registerUpkeep(
        address lottery,
        uint32 callbackGasLimit,
        address link,
        address automationRegistrar,
        uint256 deployerKey
    ) public {
        // Skip on local chain
        if (block.chainid == 31337) {
            console.log("Local chain detected. Skipping upkeep registration.");
            return;
        }

        vm.startBroadcast(deployerKey);

        // Approve LINK for registrar
        (bool success,) =
            link.call(abi.encodeWithSignature("approve(address,uint256)", automationRegistrar, FUND_AMOUNT));
        require(success, "LINK approve failed");

        AutomationRegistrar2_1.RegistrationParams memory params = AutomationRegistrar2_1.RegistrationParams({
            name: "Lottery Upkeep",
            encryptedEmail: "",
            upkeepContract: lottery,
            gasLimit: callbackGasLimit,
            adminAddress: vm.addr(deployerKey),
            triggerType: 0,
            checkData: "",
            triggerConfig: "",
            offchainConfig: "",
            amount: FUND_AMOUNT
        });

        uint256 upkeepID = AutomationRegistrar2_1(automationRegistrar).registerUpkeep(params);

        console.log("Upkeep registered with ID:", upkeepID);

        vm.stopBroadcast();
    }

    function run() external {
        address lottery = DevOpsTools.get_most_recent_deployment("Lottery", block.chainid);

        registerUpkeepUsingConfig(lottery);
    }
}

/// @title Entering the Lottery
/// @author Sushobhan Pathare
/// @notice This contract enables the user to enter the lottery with the given entrance fee
contract EnterLottery is Script {
    function enterLottery(address lottery, uint256 entranceFee, uint256 deployerKey) public {
        console.log("Entering Lottery at:", lottery);

        vm.startBroadcast(deployerKey);
        Lottery(payable(lottery)).enterLottery{value: entranceFee}();
        vm.stopBroadcast();
    }

    function enterLotteryUsingConfig(address lottery) public {
        HelperConfig helperConfig = new HelperConfig();
        (uint256 entranceFee,,,,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        enterLottery(lottery, entranceFee, deployerKey);
    }

    function run() external {
        address lottery = DevOpsTools.get_most_recent_deployment("Lottery", block.chainid);
        enterLotteryUsingConfig(lottery);
    }
}
