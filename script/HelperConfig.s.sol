//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/Linktoken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFees;
        uint256 interval;
        address vrfcoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackgaslimit;
        address link;
        uint256 deployerKey;
    }

    uint256 public constant Default_Anvil_key =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getEthMainnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFees: 0.01 ether,
                interval: 30,
                vrfcoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 5069,
                callbackgaslimit: 500000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfcoordinator != address(0)) {
            return activeNetworkConfig; // if this is true that means we can it's been populated.
        }

        uint96 baseFee = 0.25 ether; //0.25 links
        uint96 gasPriceLink = 1e9; //1 gwei

        vm.startBroadcast(Default_Anvil_key);
        VRFCoordinatorV2Mock vrfCoordinatorMock = new VRFCoordinatorV2Mock(
            baseFee,
            gasPriceLink
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        return
            NetworkConfig({
                entranceFees: 0.01 ether,
                interval: 30,
                vrfcoordinator: address(vrfCoordinatorMock),
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionId: 0, //our script will adjust it!
                callbackgaslimit: 500000,
                link: address(link),
                deployerKey: Default_Anvil_key
            });
    }

    function getEthMainnetConfig() public view returns (NetworkConfig memory) {
        return
            NetworkConfig({
                entranceFees: 0.01 ether,
                interval: 30,
                vrfcoordinator: 0x271682DEB8C4E0901D1a1550aD2e64D568E69909,
                gasLane: 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef,
                subscriptionId: 5069,
                callbackgaslimit: 500000,
                link: 0x514910771AF9Ca656af840dff83E8264EcF986CA,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }
}
