// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {ArbToken} from "../test/mocks/ArbToken.sol";

abstract contract CodeConstants {
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;

    address public FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;

    uint256 public constant ARB_SEPOLIA_CHAIN_ID = 421614;
    uint256 public constant ARB_MAINNET_CHAIN_ID = 42161;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    uint256 public constant MAX_DEPOSIT_AMOUNT = 10 ether;
    uint256 public constant MAX_LUCKY_NUMBER = 100;
}

contract HelperConfig is Script, CodeConstants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 maxDepositAmount;
        uint256 maxLuckyNumber;
        address arbAdress;
        address vrfCoordinator;
        bytes32 keyHash;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address linkToken;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ARB_SEPOLIA_CHAIN_ID] = getArbSepoliaConfig();
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getEthSepoliaConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function setConfig(uint256 chainId, NetworkConfig memory networkConfig) public {
        networkConfigs[chainId] = networkConfig;
    }

    function getArbSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            maxDepositAmount: MAX_DEPOSIT_AMOUNT,
            maxLuckyNumber: MAX_LUCKY_NUMBER,
            arbAdress: address(0),
            vrfCoordinator: 0x5CE8D5A2BC84beb22a398CCA51996F7930313D61,
            keyHash: 0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            linkToken: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
            account: address(0) // Account address
        });
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            maxDepositAmount: MAX_DEPOSIT_AMOUNT,
            maxLuckyNumber: MAX_LUCKY_NUMBER,
            arbAdress: address(0),
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: address(0) // Account address
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock =
            new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK, MOCK_WEI_PER_UINT_LINK);
        LinkToken linkToken = new LinkToken();
        ArbToken arbToken = new ArbToken();
        uint256 subscriptionId = vrfCoordinatorMock.createSubscription();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            maxDepositAmount: MAX_DEPOSIT_AMOUNT,
            maxLuckyNumber: MAX_LUCKY_NUMBER,
            arbAdress: address(arbToken),
            vrfCoordinator: address(vrfCoordinatorMock),
            keyHash: 0x1770bdc7eec7771f7ba4ffd640f34260d7f095b79c92d34a5b2551d6f6cfd2be,
            subscriptionId: subscriptionId,
            callbackGasLimit: 500000,
            linkToken: address(linkToken),
            account: FOUNDRY_DEFAULT_SENDER
        });

        return localNetworkConfig;
    }
}
