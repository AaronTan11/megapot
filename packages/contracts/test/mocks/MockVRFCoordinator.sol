// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MegaPot} from "../../src/MegaPot.sol";
import {GelatoVRFConsumerBase} from "@gelatonetwork/GelatoVRFConsumerBase.sol";

/**
 * @title MockGelatoOperator
 * @notice Mock contract to simulate Gelato VRF operator for testing
 * @dev Allows tests to trigger fulfillRandomness with controlled random values
 */
contract MockGelatoOperator {
    uint256 public requestIdCounter;

    /// @notice Event to track randomness requests in tests
    event RandomnessRequested(uint256 indexed requestId, bytes extraData);

    /**
     * @notice Fulfill randomness for a MegaPot contract
     * @dev Simulates Gelato calling fulfillRandomness on the consumer
     * @param consumer The MegaPot contract address
     * @param randomness The random value to provide
     * @param requestId The request ID (matches what was returned by _requestRandomness)
     * @param extraData The extra data that was encoded (contains round ID)
     */
    function fulfillRandomness(
        address consumer,
        uint256 randomness,
        uint256 requestId,
        bytes memory extraData
    ) external {
        // Encode dataWithRound as Gelato VRF does
        // Format: abi.encode(round, abi.encode(requestId, extraData))
        uint256 drandRound = block.timestamp; // Simulated drand round
        bytes memory innerData = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(drandRound, innerData);

        // Call fulfillRandomness on the consumer
        GelatoVRFConsumerBase(consumer).fulfillRandomness(randomness, dataWithRound);
    }

    /**
     * @notice Helper to fulfill randomness with just round ID
     * @dev Convenience function that encodes the round ID automatically
     * @param consumer The MegaPot contract address
     * @param randomness The random value to provide
     * @param requestId The request ID
     * @param roundId The game round ID to encode
     */
    function fulfillRandomnessForRound(
        address consumer,
        uint256 randomness,
        uint256 requestId,
        uint256 roundId
    ) external {
        bytes memory extraData = abi.encode(roundId);
        
        // Encode dataWithRound as Gelato VRF does
        uint256 drandRound = block.timestamp;
        bytes memory innerData = abi.encode(requestId, extraData);
        bytes memory dataWithRound = abi.encode(drandRound, innerData);

        GelatoVRFConsumerBase(consumer).fulfillRandomness(randomness, dataWithRound);
    }
}
