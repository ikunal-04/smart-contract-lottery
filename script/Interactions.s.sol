//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/Linktoken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfcoordinator, , , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        return createSubscription(vrfcoordinator, deployerKey);
    }

    function createSubscription(
        address vrfcoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Your chainId is:", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfcoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subId is:", subId);
        return subId;
    }

    function run() public returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant Fund_Amount = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfcoordinator,
            ,
            uint64 subId,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfcoordinator, subId, link, deployerKey);
    }

    function fundSubscription(
        address vrfcoordinator,
        uint64 subId,
        address link,
        uint256 deployerKey
    ) public {
        console.log("Funding Subscription: ", subId);
        console.log("Using VrfCoordinator: ", vrfcoordinator);
        console.log("On ChainId: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfcoordinator).fundSubscription(
                subId,
                Fund_Amount
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfcoordinator,
                Fund_Amount,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address rafflelottery,
        address vrfcoordinator,
        uint64 subId,
        uint256 deployerKey
    ) public {
        console.log("Adding Consumer: ", rafflelottery);
        console.log("Using VrfCoordinator: ", vrfcoordinator);
        console.log("On ChainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfcoordinator).addConsumer(subId, rafflelottery);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address Lottery) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfcoordinator,
            ,
            uint64 subId,
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(Lottery, vrfcoordinator, subId, deployerKey);
    }

    function run() external {
        address lottery = DevOpsTools.get_most_recent_deployment(
            "lottery",
            block.chainid
        );
        addConsumerUsingConfig(lottery);
    }
}
