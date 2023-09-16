// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title  Smart Contract Lottery
 * @author Kunal Garg
 * @notice This contract is performs actions done in lottery
 * @dev    Implements ChainLink VRFv2
 */

contract lottery is VRFConsumerBaseV2 {
    error NotEnoughETH();
    error Amount_TransactionFailed();
    error lottery_lotteryNotOpen();
    error lottery_UpkeepNotNeeded(
        uint256 balance,
        uint256 players,
        uint256 lotterystate
    );

    /** Type Declarations*/
    enum Lottery {
        Open, //0
        Calculating //1
    }

    /** State Variables */
    uint16 private constant Request_Confirmations = 3;
    uint32 private constant Random_words = 1;

    uint256 private immutable i_entranceFee;
    // @dev Duration of lottery in seconds
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfcoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callBackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    Lottery private s_lottery;
    address private s_recentWinner;

    /* EVENTS */
    event enteredLottery(address indexed player);
    event PickedWinner(address indexed winner);
    event RequestedLotteryWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFees,
        uint256 interval,
        address vrfcoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackgaslimit
    ) VRFConsumerBaseV2(vrfcoordinator) {
        i_entranceFee = entranceFees;
        i_interval = interval;
        i_vrfcoordinator = VRFCoordinatorV2Interface(vrfcoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callBackGasLimit = callbackgaslimit;
        s_lastTimeStamp = block.timestamp;
        s_lottery = Lottery.Open;
    }

    // Checks, Effects and Interactions

    function enterLottery() public payable {
        // Checks
        if (msg.value < i_entranceFee) {
            revert NotEnoughETH();
        }
        if (s_lottery != Lottery.Open) {
            revert lottery_lotteryNotOpen();
        }
        s_players.push(payable(msg.sender));

        emit enteredLottery(msg.sender);
    }

    /**@dev
     * 1. time intervals has passed between lottery runs
     * 2. lottery has an lottery.open state
     * 3. contract has eth (aka player)
     * 4. (implicit) subscription is funded with the link
     */

    function checkUpKeep(
        //this function is for automation
        bytes memory /**checkdata */
    ) public view returns (bool upKeepNeeded, bytes memory /**performData */) {
        bool blocktimestamp = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = Lottery.Open == s_lottery;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = blocktimestamp && isOpen && hasBalance && hasPlayers;
        return (upKeepNeeded, "0x0");
    }

    function performUpKeep(bytes memory /**performData */) external {
        (bool upKeepNeeded, ) = checkUpKeep("");
        if (!upKeepNeeded) {
            revert lottery_UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_lottery)
            );
        }
        // this is to check if enough time has passed
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert();
        }
        s_lottery = Lottery.Calculating;
        uint256 requestId = i_vrfcoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            Request_Confirmations,
            i_callBackGasLimit,
            Random_words
        );
        emit RequestedLotteryWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /**requestId*/,
        uint256[] memory randomWords
    ) internal override {
        // s_players = 10
        // random = 12
        // 12 % 10 -> 2
        // 123165464684165189198134357316169845453498 % 10 -> 8

        // Effects (Our own contract)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_lottery = Lottery.Open;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        emit PickedWinner(winner);

        //Interactions (Other Contracts)
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Amount_TransactionFailed();
        }
    }

    function getLotteryState() external view returns (Lottery) {
        return s_lottery;
    }

    function getPlayers(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
