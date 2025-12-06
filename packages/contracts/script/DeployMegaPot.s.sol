// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MegaPot} from "../src/MegaPot.sol";

/**
 * @title DeployMegaPot
 * @notice Deployment script for MegaPot game contract with Gelato VRF
 *
 * Usage:
 *   # Dry run (simulation)
 *   forge script script/DeployMegaPot.s.sol --rpc-url $RPC_URL
 *
 *   # Broadcast to network (MegaETH Timothy Testnet)
 *   forge script script/DeployMegaPot.s.sol --rpc-url https://timothy.megaeth.com/rpc --broadcast
 *
 *   # With verification
 *   forge script script/DeployMegaPot.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Required Environment Variables:
 *   DEPLOYER_PRIVATE_KEY    - Private key of the deployer account
 *   GELATO_OPERATOR         - Gelato VRF operator address (from Gelato dashboard)
 *   USDM_ADDRESS            - USDm token contract address
 *
 * Optional Environment Variables:
 *   ROUND_DURATION          - Round duration in seconds (default: 300 = 5 min)
 *   PLATFORM_FEE_BPS        - Platform fee in basis points (default: 500 = 5%)
 *   NUMBER_PRICE            - Price per number in USDm units (default: 1000000 = $1)
 *
 * Post-Deployment Steps:
 *   1. Go to https://app.gelato.network/
 *   2. Connect wallet to MegaETH Testnet (Chain ID: 6343)
 *   3. Create new VRF task with MegaPot contract address
 *   4. Note the dedicated msg.sender (should match GELATO_OPERATOR)
 */
contract DeployMegaPot is Script {
    // Default configuration values
    uint256 public constant DEFAULT_ROUND_DURATION = 300; // 5 minutes
    uint256 public constant DEFAULT_PLATFORM_FEE_BPS = 500; // 5%
    uint256 public constant DEFAULT_NUMBER_PRICE = 1_000_000; // $1 (6 decimals)

    function run() external returns (MegaPot megaPot) {
        // Get deployer address from private key
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Load Gelato VRF operator address
        address gelatoOperator = vm.envAddress("GELATO_OPERATOR");

        // Load token address
        address usdmAddress = vm.envAddress("USDM_ADDRESS");

        // Load optional game configuration with defaults
        uint256 roundDuration = vm.envOr("ROUND_DURATION", DEFAULT_ROUND_DURATION);
        uint256 platformFeeBps = vm.envOr("PLATFORM_FEE_BPS", DEFAULT_PLATFORM_FEE_BPS);
        uint256 numberPrice = vm.envOr("NUMBER_PRICE", DEFAULT_NUMBER_PRICE);

        // Build round config
        MegaPot.RoundConfig memory roundConfig = MegaPot.RoundConfig({
            roundDuration: roundDuration,
            platformFeeBps: platformFeeBps,
            numberPrice: numberPrice,
            token: IERC20(usdmAddress)
        });

        // Log deployment parameters
        console2.log("Deploying MegaPot on MegaETH...");
        console2.log("========================================");
        console2.log("Deployer:", deployer);
        console2.log("----------------------------------------");
        console2.log("Gelato VRF Configuration:");
        console2.log("  Operator:", gelatoOperator);
        console2.log("----------------------------------------");
        console2.log("Game Configuration:");
        console2.log("  Token (USDm):", usdmAddress);
        console2.log("  Round Duration:", roundDuration, "seconds");
        console2.log("  Platform Fee:", platformFeeBps, "bps");
        console2.log("  Number Price:", numberPrice, "tokens");
        console2.log("========================================");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MegaPot with Gelato VRF
        megaPot = new MegaPot(
            deployer,       // initialOwner
            gelatoOperator, // Gelato VRF operator
            roundConfig     // Initial round config
        );

        vm.stopBroadcast();

        console2.log("");
        console2.log("========================================");
        console2.log("DEPLOYMENT SUCCESSFUL!");
        console2.log("========================================");
        console2.log("MegaPot deployed at:", address(megaPot));
        console2.log("Current round ID:", megaPot.currentRoundId());
        console2.log("========================================");
        console2.log("");
        console2.log("NEXT STEPS:");
        console2.log("1. Go to https://app.gelato.network/");
        console2.log("2. Connect wallet to MegaETH Testnet (Chain ID: 6343)");
        console2.log("3. Create a new VRF task:");
        console2.log("   - Select 'VRF' service");
        console2.log("   - Enter contract address:", address(megaPot));
        console2.log("4. Gelato will auto-listen for RequestedRandomness events");
        console2.log("========================================");

        return megaPot;
    }
}
