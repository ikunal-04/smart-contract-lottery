//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {lottery} from "../../src/lottery.sol";
import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract LotteryTest is Test {
    lottery public t_Lottery;
    event enteredLottery(address indexed player);

    address public Player = makeAddr("player");
    uint256 public constant Starting_player_Balance = 10 ether;

    HelperConfig public helperConfig = new HelperConfig();
    uint256 entranceFees;
    uint256 interval;
    address vrfcoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackgaslimit;
    address link;

    function setUp() external {
        DeployLottery deploylottery = new DeployLottery();
        (t_Lottery, helperConfig) = deploylottery.run();
        (
            entranceFees,
            interval,
            vrfcoordinator,
            gasLane,
            subscriptionId,
            callbackgaslimit,
            link,

        ) = helperConfig.activeNetworkConfig();
        vm.deal(Player, Starting_player_Balance);
    }

    function testlotteryInitializeInOpenState() public view {
        assert(t_Lottery.getLotteryState() == lottery.Lottery.Open);
    }

    function testRevertIfDontEnoughEthPaid() public {
        vm.prank(Player);
        vm.expectRevert(lottery.NotEnoughETH.selector);
        t_Lottery.enterLottery();
    }

    function testLotteryRecordsPlayersWhenTheyEnter() public {
        vm.prank(Player);
        t_Lottery.enterLottery{value: Starting_player_Balance}();

        address player = t_Lottery.getPlayers(0);
        assert(player == Player);
    }

    function testEmitEventsOnEntrance() public {
        vm.prank(Player);
        vm.expectEmit(true, false, false, false, address(t_Lottery));
        emit enteredLottery(Player);
        t_Lottery.enterLottery{value: entranceFees}();
    }

    function testCantEnterWhenLotteryIsCalculating()
        public
        LotteryenteredAndTimePassed
    {
        t_Lottery.performUpKeep("");

        vm.expectRevert(lottery.lottery_lotteryNotOpen.selector);
        vm.prank(Player);
        t_Lottery.enterLottery{value: entranceFees}();
    }

    function testCheckUpKeepReturnsFalseIfNotHasEnoughBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upKeepNeeded, ) = t_Lottery.checkUpKeep("");

        assert(upKeepNeeded == false);
    }

    function testCheckUpKeepReturnsFalseIfLotteryNotOpen()
        public
        LotteryenteredAndTimePassed
    {
        t_Lottery.performUpKeep("");

        (bool upkeepneeded, ) = t_Lottery.checkUpKeep("");

        assert(upkeepneeded == false);
    }

    function testCheckUpKeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.prank(Player);
        t_Lottery.enterLottery{value: entranceFees}();
        vm.roll(block.number + 1);

        (bool upkeepneeded, ) = t_Lottery.checkUpKeep("");

        assert(upkeepneeded == false);
    }

    modifier LotteryenteredAndTimePassed() {
        vm.prank(Player);
        t_Lottery.enterLottery{value: entranceFees}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testCheckUpKeepReturnsTrueWhenAllGood()
        public
        LotteryenteredAndTimePassed
    {
        (bool upkeepneeded, ) = t_Lottery.checkUpKeep("");

        assert(upkeepneeded == true);
    }

    // performUpKeepNeeded tests

    function testPerformKeepCanOnlyRunIfCheckUpIsTrue() public {
        vm.prank(Player);
        t_Lottery.enterLottery{value: entranceFees}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        t_Lottery.performUpKeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numberPlayers = 0;
        uint256 raffleState = 0;

        vm.expectRevert(
            abi.encodeWithSelector(
                lottery.lottery_UpkeepNotNeeded.selector,
                currentBalance,
                numberPlayers,
                raffleState
            )
        );

        t_Lottery.performUpKeep("");
    }

    function testPerformKeepUpdatesLotteryStateAndEmitRequestId()
        public
        LotteryenteredAndTimePassed
    {
        vm.recordLogs();
        t_Lottery.performUpKeep(""); //emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        lottery.Lottery rstate = t_Lottery.getLotteryState();

        assert(uint256(requestId) > 0);
        assert(uint256(rstate) == 1);
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandommWordsCanOnlyBeCallAfterPerformUpKeep(
        uint256 randomRequestId
    ) public LotteryenteredAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfcoordinator).fulfillRandomWords(
            randomRequestId,
            address(t_Lottery)
        );

        vm.expectRevert("nonexistent request");

        VRFCoordinatorV2Mock(vrfcoordinator).fulfillRandomWords(
            1,
            address(t_Lottery)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        LotteryenteredAndTimePassed
        skipFork
    {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrances;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            t_Lottery.enterLottery{value: entranceFees}();
        }

        uint256 startingTimeStamp = t_Lottery.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        t_Lottery.performUpKeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2Mock(vrfcoordinator).fulfillRandomWords(
            uint256(requestId),
            address(t_Lottery)
        );

        // Assert
        address recentWinner = t_Lottery.getRecentWinner();
        lottery.Lottery raffleState = t_Lottery.getLotteryState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = t_Lottery.getLastTimeStamp();
        uint256 prize = entranceFees * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
