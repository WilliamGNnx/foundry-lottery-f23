// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        AddConsumer addConsumer = new AddConsumer();

        if (config.subscriptionId == 0) {
            /** @dev < 1st > create subscription
             * VRF Coordinator was deployed on blockchain testnets or mainnet.
             * In order to obtain services, we must create subscription through coordinator contract.
             * If we test with anvil local network, deploy VRFCoordinatorV2_5Mock.sol and create subscription by it.
             */
            CreateSubscription createSubscription = new CreateSubscription();
            (
                config.subscriptionId,
                config.vrfCoordinatorV2_5
            ) = createSubscription.createSubscription(
                config.vrfCoordinatorV2_5,
                config.account
            );
            /** @dev < 2nd > fund subscription
             *  In subscription method for requesting randomness, user should fund its balance.
             *  When consuming contract request randomness, the transaction costs are calculated after the randomness request are fulfilled
             *  and the subscription balance is deducted accordingly.
             */
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinatorV2_5,
                config.subscriptionId,
                config.link,
                config.account
            );

            helperConfig.setConfig(block.chainid, config);
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.subscriptionId,
            config.gasLane,
            config.automationUpdateInterval,
            config.raffleEntranceFee,
            config.callbackGasLimit,
            config.vrfCoordinatorV2_5
        );
        vm.stopBroadcast();

        /** @dev < 3rd > add consumer to subscription
         *  Add consumer contract address to subscription.
         *  Consumer contract will call subscription.requestRandomWords() to request randomness.
         */
        addConsumer.addConsumer(
            address(raffle),
            config.vrfCoordinatorV2_5,
            config.subscriptionId,
            config.account
        );
        return (raffle, helperConfig);
    }
}
