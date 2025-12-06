// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {USDm} from "../src/USDm.sol";

/**
 * @title DeployUSDm
 * @notice Deployment script for USDm mock stablecoin
 * @dev For testnet/local development use only
 *
 * Usage:
 *   # Dry run (simulation)
 *   forge script script/DeployUSDm.s.sol --rpc-url $RPC_URL
 *
 *   # Broadcast to network
 *   forge script script/DeployUSDm.s.sol --rpc-url $RPC_URL --broadcast
 *
 *   # With verification
 *   forge script script/DeployUSDm.s.sol --rpc-url $RPC_URL --broadcast --verify
 *
 * Environment Variables:
 *   DEPLOYER_PRIVATE_KEY - Private key of the deployer account
 *   INITIAL_MINT_AMOUNT  - (Optional) Initial tokens to mint (default: 1,000,000 USDm)
 */
contract DeployUSDm is Script {
    // Default initial mint: 1,000,000 USDm (with 6 decimals)
    uint256 public constant DEFAULT_INITIAL_MINT = 1_000_000 * 1e6;

    function run() external returns (USDm usdm) {
        // Get deployer address from private key
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get optional initial mint amount
        uint256 initialMint = vm.envOr("INITIAL_MINT_AMOUNT", DEFAULT_INITIAL_MINT);

        console2.log("Deploying USDm mock stablecoin...");
        console2.log("Deployer:", deployer);
        console2.log("Initial mint:", initialMint);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy USDm with deployer as initial owner
        usdm = new USDm(deployer);

        // Mint initial supply to deployer (for faucet/testing)
        if (initialMint > 0) {
            usdm.mint(deployer, initialMint);
            console2.log("Minted", initialMint, "tokens to deployer");
        }

        vm.stopBroadcast();

        console2.log("USDm deployed at:", address(usdm));
        console2.log("Token name:", usdm.name());
        console2.log("Token symbol:", usdm.symbol());
        console2.log("Token decimals:", usdm.decimals());
        console2.log("Deployer balance:", usdm.balanceOf(deployer));

        return usdm;
    }
}

