// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {LuckyArb} from "../src/LuckyArb.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";
import {ArbToken} from "../test/mocks/ArbToken.sol";

contract DeployLuckyArb is Script {
    function run() public returns (LuckyArb, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) =
                createSubscription.createSubscription(config.vrfCoordinator, config.account);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator, config.subscriptionId, config.linkToken, config.account
            );

            helperConfig.setConfig(block.chainid, config);
        }

        if (config.arbAdress == address(0)) {
            vm.startBroadcast(config.account);
            ArbToken abrToken = new ArbToken();
            vm.stopBroadcast();
            config.arbAdress = address(abrToken);
            console.log("ArbToken contract address: %s", address(abrToken));
        }

        vm.startBroadcast(config.account);
        LuckyArb luckyArb = new LuckyArb(
            config.maxDepositAmount,
            config.maxLuckyNumber,
            config.arbAdress,
            config.vrfCoordinator,
            config.keyHash,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(luckyArb), config.vrfCoordinator, config.subscriptionId, config.account);
        return (luckyArb, helperConfig);
    }
}
