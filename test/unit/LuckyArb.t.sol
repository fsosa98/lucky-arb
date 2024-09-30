// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployLuckyArb} from "../../script/DeployLuckyArb.s.sol";
import {LuckyArb} from "../../src/LuckyArb.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {LinkToken} from "../mocks/LinkToken.sol";
import {ArbToken} from "../mocks/ArbToken.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract DSCEngineTest is Test, CodeConstants {
    LuckyArb public luckyArb;
    HelperConfig public helperConfig;

    uint256 public maxDepositAmount;
    uint256 public maxLuckyNumber;
    ArbToken public arbToken;
    address public vrfCoordinator;
    uint256 public subscriptionId;
    LinkToken public linkToken;

    address public owner;
    address[] public players;

    uint256 public constant STARTING_BALANCE = 20 ether;
    uint256 public constant PLAYER_DEPOSIT_AMOUNT = 1 ether;
    uint256 public constant LOTTERY_DURATION = 1 days;
    uint256 public constant REWARD = 5 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    function setUp() external {
        DeployLuckyArb deployer = new DeployLuckyArb();
        (luckyArb, helperConfig) = deployer.run();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        maxDepositAmount = config.maxDepositAmount;
        maxLuckyNumber = config.maxLuckyNumber;
        arbToken = ArbToken(config.arbAdress);
        vrfCoordinator = config.vrfCoordinator;
        subscriptionId = config.subscriptionId;
        linkToken = LinkToken(config.linkToken);
        owner = config.account;

        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            linkToken.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, LINK_BALANCE);

            for (uint256 i = 0; i < 4; i++) {
                players.push(address(uint160(i + 1)));
                arbToken.mint(players[i], STARTING_BALANCE);
                vm.deal(players[i], STARTING_BALANCE);
            }
        }
        linkToken.approve(vrfCoordinator, LINK_BALANCE);
        vm.stopPrank();
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    modifier startLottery() {
        vm.prank(owner);
        luckyArb.startLottery(LOTTERY_DURATION, REWARD);
        _;
    }

    // Token Deposit Tests
    function testPlayerCannotDepositBeforeLotteryStarts() public skipFork {
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), PLAYER_DEPOSIT_AMOUNT);

        vm.expectRevert(LuckyArb.LuckyArb__LotteryClosed.selector);
        luckyArb.depositTokens(PLAYER_DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testPlayerCanDepositWhenLotteryOpen() public startLottery skipFork {
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), PLAYER_DEPOSIT_AMOUNT);
        luckyArb.depositTokens(PLAYER_DEPOSIT_AMOUNT);
        vm.stopPrank();

        uint256 depositedAmount = luckyArb.getPlayerDepositedAmount(players[0]);
        assertEq(PLAYER_DEPOSIT_AMOUNT, depositedAmount);
    }

    function testPlayerCannotDepositAfterLotteryClose() public startLottery skipFork {
        vm.warp(block.timestamp + 1 days + 1);
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), PLAYER_DEPOSIT_AMOUNT);

        vm.expectRevert(LuckyArb.LuckyArb__LotteryClosed.selector);
        luckyArb.depositTokens(PLAYER_DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testPlayerCannotDepositMoreThanMaxDepositAmount() public startLottery skipFork {
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), maxDepositAmount + 1 ether);

        vm.expectRevert(LuckyArb.LuckyArb__InvalidDepositAmount.selector);
        luckyArb.depositTokens(maxDepositAmount + 1 ether);
        vm.stopPrank();
    }

    // Token Withdrawal Tests
    function testPlayerCannotWithdrawBeforeDeposit() public {
        vm.startPrank(players[0]);
        vm.expectRevert(LuckyArb.LuckyArb__InvalidWithdrawalAmount.selector);
        luckyArb.withdrawTokens(PLAYER_DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    function testPlayerCanWithdrawAfterDeposit() public startLottery skipFork {
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), PLAYER_DEPOSIT_AMOUNT);

        luckyArb.depositTokens(PLAYER_DEPOSIT_AMOUNT);
        uint256 depositedAmountBeforeWithdrawal = luckyArb.getPlayerDepositedAmount(players[0]);
        luckyArb.withdrawTokens(PLAYER_DEPOSIT_AMOUNT);
        uint256 depositedAmountAfterWithdrawal = luckyArb.getPlayerDepositedAmount(players[0]);
        vm.stopPrank();

        assertEq(PLAYER_DEPOSIT_AMOUNT, depositedAmountBeforeWithdrawal);
        assertEq(0, depositedAmountAfterWithdrawal);
    }

    function testPlayerCannotWithdrawMoreThanDeposited() public startLottery skipFork {
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), PLAYER_DEPOSIT_AMOUNT);
        luckyArb.depositTokens(PLAYER_DEPOSIT_AMOUNT);

        vm.expectRevert(LuckyArb.LuckyArb__InvalidWithdrawalAmount.selector);
        luckyArb.withdrawTokens(PLAYER_DEPOSIT_AMOUNT + 1 ether);
        vm.stopPrank();
    }

    // Pick a Number Tests
    function testPlayerCannotPickNumberBeforeLotteryStarts() public {
        vm.startPrank(players[0]);
        vm.expectRevert(LuckyArb.LuckyArb__LotteryClosed.selector);
        luckyArb.pickNumber(1);
        vm.stopPrank();
    }

    function testPlayerCannotPickNumberLowerThanOne() public startLottery skipFork {
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), PLAYER_DEPOSIT_AMOUNT);
        luckyArb.depositTokens(PLAYER_DEPOSIT_AMOUNT);

        uint256 number = 0;
        vm.expectRevert(LuckyArb.LuckyArb__InvalidNumber.selector);
        luckyArb.pickNumber(number);
        vm.stopPrank();
    }

    function testPlayerCannotPickNumberGreaterThanMaxLuckyNumber() public startLottery skipFork {
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), PLAYER_DEPOSIT_AMOUNT);
        luckyArb.depositTokens(PLAYER_DEPOSIT_AMOUNT);

        vm.expectRevert(LuckyArb.LuckyArb__InvalidNumber.selector);
        luckyArb.pickNumber(maxLuckyNumber + 1);
        vm.stopPrank();
    }

    function testPlayerCanPickNumberAfterDeposit() public startLottery skipFork {
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), PLAYER_DEPOSIT_AMOUNT);
        luckyArb.depositTokens(PLAYER_DEPOSIT_AMOUNT);

        uint256 number = 1;
        luckyArb.pickNumber(number);
        vm.stopPrank();

        assertEq(number, luckyArb.getPlayerNumber(players[0]));
    }

    function testPlayerCanChangePickedNumber() public startLottery skipFork {
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), PLAYER_DEPOSIT_AMOUNT);
        luckyArb.depositTokens(PLAYER_DEPOSIT_AMOUNT);
        uint256 numberBefore = 1;
        luckyArb.pickNumber(numberBefore);
        uint256 numberBeforeFromGetter = luckyArb.getPlayerNumber(players[0]);

        uint256 numberAfter = 10;
        luckyArb.pickNumber(numberAfter);
        vm.stopPrank();

        assertEq(numberBefore, numberBeforeFromGetter);
        assertEq(numberAfter, luckyArb.getPlayerNumber(players[0]));
    }

    function testPlayerCannotPickNumberAfterLotteryClose() public startLottery skipFork {
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), PLAYER_DEPOSIT_AMOUNT);
        luckyArb.depositTokens(PLAYER_DEPOSIT_AMOUNT);

        vm.warp(block.timestamp + 1 days + 1);
        vm.expectRevert(LuckyArb.LuckyArb__LotteryClosed.selector);
        luckyArb.pickNumber(1);
        vm.stopPrank();
    }

    // Requesting a Lucky Number and Claiming Rewards Tests
    function testPlayerCannotClaimRewardIfDepositAmountTooLow() public startLottery skipFork {
        uint256 minDepositAmount = luckyArb.MIN_DEPOSIT_AMOUNT();
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), minDepositAmount - 1);
        luckyArb.depositTokens(minDepositAmount - 1);
        luckyArb.pickNumber(62);
        vm.stopPrank();
        vm.warp(block.timestamp + LOTTERY_DURATION + 1);

        vm.recordLogs();
        vm.prank(owner);
        luckyArb.requestLuckyNumber();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(luckyArb));
        console2.log("Lucky number: %s", luckyArb.getLuckyNumber()); // Lucky number: 62

        vm.startPrank(players[0]);
        vm.expectRevert(LuckyArb.LuckyArb__InvalidDepositAmount.selector);
        luckyArb.claimReward();
        vm.stopPrank();
    }

    function testPlayersCanClaimTheirRewards() public startLottery skipFork {
        uint256 pickedLuckyNumber = 62; // Lucky number generated by VRFCoordinatorV2_5Mock is 62

        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), PLAYER_DEPOSIT_AMOUNT);
        luckyArb.depositTokens(PLAYER_DEPOSIT_AMOUNT);
        luckyArb.pickNumber(pickedLuckyNumber);
        vm.stopPrank();

        vm.startPrank(players[1]);
        arbToken.approve(address(luckyArb), 10 ether);
        luckyArb.depositTokens(10 ether);
        luckyArb.pickNumber(pickedLuckyNumber - 9);
        vm.stopPrank();

        vm.startPrank(players[2]);
        arbToken.approve(address(luckyArb), 10 ether);
        luckyArb.depositTokens(10 ether);
        luckyArb.pickNumber(pickedLuckyNumber + 9);
        vm.stopPrank();

        vm.startPrank(players[3]);
        arbToken.approve(address(luckyArb), 10 ether);
        luckyArb.depositTokens(10 ether);
        luckyArb.pickNumber(pickedLuckyNumber + 10);
        vm.stopPrank();

        vm.warp(block.timestamp + LOTTERY_DURATION + 1);

        vm.recordLogs();
        vm.prank(owner);
        luckyArb.requestLuckyNumber();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(luckyArb));

        vm.prank(players[0]);
        luckyArb.claimReward();
        vm.prank(players[1]);
        luckyArb.claimReward();
        vm.prank(players[2]);
        luckyArb.claimReward();
        vm.prank(players[3]);
        luckyArb.claimReward();

        assertEq(REWARD, luckyArb.balanceOf(players[0]));
        assertEq(0, luckyArb.getPlayerNumber(players[0]));
        assertEq(REWARD, luckyArb.balanceOf(players[1]));
        assertEq(0, luckyArb.getPlayerNumber(players[1]));
        assertEq(REWARD, luckyArb.balanceOf(players[2]));
        assertEq(0, luckyArb.getPlayerNumber(players[2]));
        assertEq(0, luckyArb.balanceOf(players[3]));
        assertEq(0, luckyArb.getPlayerNumber(players[3]));
    }

    function testPlayerCannotClaimRewardMultipleTimes() public startLottery skipFork {
        vm.startPrank(players[0]);
        arbToken.approve(address(luckyArb), PLAYER_DEPOSIT_AMOUNT);
        luckyArb.depositTokens(PLAYER_DEPOSIT_AMOUNT);
        luckyArb.pickNumber(62);
        vm.stopPrank();
        vm.warp(block.timestamp + LOTTERY_DURATION + 1);

        vm.recordLogs();
        vm.prank(owner);
        luckyArb.requestLuckyNumber();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(luckyArb));

        vm.startPrank(players[0]);
        luckyArb.claimReward();
        vm.expectRevert(LuckyArb.LuckyArb__RewardAlreadyClaimed.selector);
        luckyArb.claimReward();
        vm.stopPrank();
    }

    // Donation Claim Tests
    function testCannotClaimIfNotOwner() public {
        vm.startPrank(players[0]);
        vm.expectRevert();
        luckyArb.claimDonations(payable(players[0]));
        vm.stopPrank();
    }

    function testCannotClaimIfThereAreNoDonations() public {
        vm.startPrank(owner);
        vm.expectRevert(LuckyArb.LuckyArb__NoDonationsToClaim.selector);
        luckyArb.claimDonations(payable(owner));
    }

    function testOwnerCanClaimDonations() public {
        uint256 ownerBalanceBefore = owner.balance;
        uint256 donation = 1 ether;

        vm.prank(players[0]);
        payable(luckyArb).call{value: donation}("");

        vm.startPrank(owner);
        luckyArb.claimDonations(payable(owner));
        uint256 ownerBalanceAfter = owner.balance;

        assertEq(ownerBalanceAfter, ownerBalanceBefore + donation);
    }

    // Set maxDepositAmount Tests
    function testPlayerCannotSetMaxDepositAmount() public {
        vm.startPrank(players[0]);
        vm.expectRevert();
        luckyArb.setMaxDepositAmount(1000 ether);
        vm.stopPrank();
    }

    function testOwnerCanSetMaxDepositAmount() public {
        vm.startPrank(owner);
        uint256 newMaxDepositAmount = 1000 ether;
        luckyArb.setMaxDepositAmount(newMaxDepositAmount);
        vm.stopPrank();

        assertEq(newMaxDepositAmount, luckyArb.getMaxDepositAmount());
    }

    function testOwnerCannotSetMaxDepositAmountWhenLotteryOpen() public startLottery {
        vm.startPrank(owner);
        vm.expectRevert(LuckyArb.LuckyArb__LotteryOpen.selector);
        luckyArb.setMaxDepositAmount(1000 ether);
        vm.stopPrank();
    }

    // Set maxLuckyNumber Tests
    function testPlayerCannotSetMaxLuckyNumber() public {
        vm.startPrank(players[0]);
        vm.expectRevert();
        luckyArb.setMaxLuckyNumber(10);
        vm.stopPrank();
    }

    function testOwnerCanSetLuckyNumber() public {
        vm.startPrank(owner);
        uint256 newMaxLuckyNumber = 10;
        luckyArb.setMaxLuckyNumber(newMaxLuckyNumber);
        vm.stopPrank();

        assertEq(newMaxLuckyNumber, luckyArb.getMaxLuckyNumber());
    }

    function testOwnerCannotSetMaxLuckyNumberWhenLotteryOpen() public startLottery {
        vm.startPrank(owner);
        vm.expectRevert(LuckyArb.LuckyArb__LotteryOpen.selector);
        luckyArb.setMaxLuckyNumber(10);
        vm.stopPrank();
    }
}
