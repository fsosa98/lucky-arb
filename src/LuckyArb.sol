// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract LuckyArb is ERC20, VRFConsumerBaseV2Plus {
    // Errors
    error LuckyArb__LotteryClosed();
    error LuckyArb__LotteryOpen();
    error LuckyArb__InvalidDepositAmount();
    error LuckyArb__InvalidWithdrawalAmount();
    error LuckyArb__InvalidNumber();
    error LuckyArb__LuckyNumberNotPicked();
    error LuckyArb__RewardAlreadyClaimed();
    error LuckyArb__TransferFailed();
    error LuckyArb__NoDonationsToClaim();

    // State variables
    uint256 public constant MIN_DEPOSIT_AMOUNT = 1 ether;
    uint256 public constant MIN_LUCKY_NUMBER = 1;
    uint16 public constant REQUEST_CONFIRMATIONS = 3;
    uint32 public constant NUM_WORDS = 1;

    IERC20 private immutable i_arbToken;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subId;
    uint32 private immutable i_callbackGasLimit;

    uint256 private s_luckyNumber;
    uint256 private s_lotteryDuration;
    uint256 private s_reward;
    uint256 private s_lotteryStartAt;
    uint256 private s_maxDepositAmount;
    uint256 private s_maxLuckyNumber;
    mapping(address => uint256) private s_playerToNumber;
    mapping(address => uint256) private s_playerToDepositedAmount;

    // Events
    event Deposit(address indexed player, uint256 indexed amount);
    event Withdrawal(address indexed player, uint256 indexed amount);
    event NumberPicked(address indexed player, uint256 indexed number);
    event LuckyNumberRequested(uint256 indexed requestId);
    event LuckyNumberDrawn(uint256 indexed luckyNumber);
    event RewardClaimed(address indexed player, uint256 indexed reward);

    // Modifiers
    modifier lotteryOpen() {
        if (block.timestamp - s_lotteryStartAt > s_lotteryDuration) {
            revert LuckyArb__LotteryClosed();
        }
        _;
    }

    modifier lotteryClosed() {
        if (block.timestamp - s_lotteryStartAt <= s_lotteryDuration) {
            revert LuckyArb__LotteryOpen();
        }
        _;
    }

    // Constructor
    constructor(
        uint256 maxDepositAmount,
        uint256 maxLuckyNumber,
        address arbTokenAdress,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) ERC20("Lucky ARB", "LARB") VRFConsumerBaseV2Plus(vrfCoordinator) {
        s_maxDepositAmount = maxDepositAmount;
        s_maxLuckyNumber = maxLuckyNumber;
        i_arbToken = IERC20(arbTokenAdress);
        i_keyHash = keyHash;
        i_subId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    // receive function for receiving donations
    receive() external payable {}

    // External functions
    function startLottery(uint256 lotteryDuration, uint256 reward) external onlyOwner {
        s_luckyNumber = 0;
        s_lotteryDuration = lotteryDuration;
        s_reward = reward;
        s_lotteryStartAt = block.timestamp;
    }

    function depositTokens(uint256 depositAmount) external lotteryOpen {
        uint256 newPlayerDepositedAmount = s_playerToDepositedAmount[msg.sender] + depositAmount;
        if (newPlayerDepositedAmount > s_maxDepositAmount) {
            revert LuckyArb__InvalidDepositAmount();
        }

        i_arbToken.transferFrom(msg.sender, address(this), depositAmount);
        s_playerToDepositedAmount[msg.sender] = newPlayerDepositedAmount;

        emit Deposit(msg.sender, depositAmount);
    }

    function withdrawTokens(uint256 amountToWithdraw) external {
        uint256 playerDepositedAmount = s_playerToDepositedAmount[msg.sender];
        if (amountToWithdraw > playerDepositedAmount) {
            revert LuckyArb__InvalidWithdrawalAmount();
        }
        s_playerToDepositedAmount[msg.sender] = playerDepositedAmount - amountToWithdraw;
        i_arbToken.transfer(msg.sender, amountToWithdraw);

        emit Withdrawal(msg.sender, amountToWithdraw);
    }

    function pickNumber(uint256 number) external lotteryOpen {
        if (number < MIN_LUCKY_NUMBER || number > s_maxLuckyNumber) {
            revert LuckyArb__InvalidNumber();
        }
        s_playerToNumber[msg.sender] = number;

        emit NumberPicked(msg.sender, number);
    }

    function requestLuckyNumber() external onlyOwner lotteryClosed {
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        emit LuckyNumberRequested(requestId);
    }

    function claimReward() external lotteryClosed {
        if (s_luckyNumber == 0) {
            revert LuckyArb__LuckyNumberNotPicked();
        }

        uint256 playerDepositedAmount = s_playerToDepositedAmount[msg.sender];
        if (playerDepositedAmount < MIN_DEPOSIT_AMOUNT) {
            revert LuckyArb__InvalidDepositAmount();
        }

        uint256 number = s_playerToNumber[msg.sender];
        if (number == 0) {
            revert LuckyArb__RewardAlreadyClaimed();
        }

        s_playerToNumber[msg.sender] = 0;
        uint256 range = playerDepositedAmount / MIN_DEPOSIT_AMOUNT;
        uint256 lowerLimit = number + 1 > range ? number - range + 1 : 1;
        if (s_luckyNumber >= lowerLimit && s_luckyNumber <= number + range - 1) {
            _mint(msg.sender, s_reward);
        }

        emit RewardClaimed(msg.sender, s_reward);
    }

    function claimDonations(address payable recipient) external onlyOwner {
        uint256 contractBalance = address(this).balance;
        if (contractBalance == 0) {
            revert LuckyArb__NoDonationsToClaim();
        }

        (bool success,) = recipient.call{value: contractBalance}("");
        if (!success) {
            revert LuckyArb__TransferFailed();
        }
    }

    // Setter functions
    function setMaxDepositAmount(uint256 maxDepositAmount) external lotteryClosed onlyOwner {
        s_maxDepositAmount = maxDepositAmount;
    }

    function setMaxLuckyNumber(uint256 maxLuckyNumber) external lotteryClosed onlyOwner {
        s_maxLuckyNumber = maxLuckyNumber;
    }

    // Internal functions
    function fulfillRandomWords(uint256, uint256[] calldata randomWords) internal override {
        s_luckyNumber = (randomWords[0] % s_maxLuckyNumber) + 1;

        emit LuckyNumberDrawn(s_luckyNumber);
    }

    // Getter functions
    function getArbToken() external view returns (IERC20) {
        return i_arbToken;
    }

    function getLuckyNumber() external view returns (uint256) {
        return s_luckyNumber;
    }

    function getLotteryDuration() external view returns (uint256) {
        return s_lotteryDuration;
    }

    function getReward() external view returns (uint256) {
        return s_reward;
    }

    function getLotteryStartAt() external view returns (uint256) {
        return s_lotteryStartAt;
    }

    function getMinDepositAmount() external pure returns (uint256) {
        return MIN_DEPOSIT_AMOUNT;
    }

    function getMaxDepositAmount() external view returns (uint256) {
        return s_maxDepositAmount;
    }

    function getMinLuckyNumber() external pure returns (uint256) {
        return MIN_LUCKY_NUMBER;
    }

    function getMaxLuckyNumber() external view returns (uint256) {
        return s_maxLuckyNumber;
    }

    function getPlayerNumber(address player) external view returns (uint256) {
        return s_playerToNumber[player];
    }

    function getPlayerDepositedAmount(address player) external view returns (uint256) {
        return s_playerToDepositedAmount[player];
    }
}
