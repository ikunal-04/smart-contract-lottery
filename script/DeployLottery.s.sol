//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {lottery} from "../src/lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployLottery is Script {
    function run() external returns (lottery, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFees,
            uint256 interval,
            address vrfcoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackgaslimit,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createsubscription = new CreateSubscription();
            subscriptionId = createsubscription.createSubscription(
                vrfcoordinator,
                deployerKey
            );
            // FUND IT!!
            FundSubscription fundsubscription = new FundSubscription();
            fundsubscription.fundSubscription(
                vrfcoordinator,
                subscriptionId,
                link,
                deployerKey
            );
        }

        vm.startBroadcast(deployerKey);
        lottery Lottery = new lottery(
            entranceFees,
            interval,
            vrfcoordinator,
            gasLane,
            subscriptionId,
            callbackgaslimit
        );
        vm.stopBroadcast();

        // AddConsumer
        AddConsumer addconsumer = new AddConsumer();
        addconsumer.addConsumer(
            address(Lottery),
            vrfcoordinator,
            subscriptionId,
            deployerKey
        );
        return (Lottery, helperConfig);
    }
}
