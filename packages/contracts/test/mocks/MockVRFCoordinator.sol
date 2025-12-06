// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GelatoVRFConsumerBase} from "@gelatonetwork/GelatoVRFConsumerBase.sol";

/**
 * @title MockGelatoOperator
 * @notice Mock contract to simulate Gelato VRF operator for testing
 * @dev Captures RequestedRandomness events and uses exact data for fulfillment
 *      to pass the hash validation in GelatoVRFConsumerBase
 */
contract MockGelatoOperator {
    // Store the last request data for each consumer
    mapping(address => mapping(uint256 => bytes)) public requestDataByConsumer;
    mapping(address => uint256) public lastRequestId;

    /// @notice Event to track when we store request data
    event RequestDataCaptured(address indexed consumer, uint256 indexed requestId, uint256 round, bytes data);

    /**
     * @notice Store request data from a RequestedRandomness event
     * @dev Call this after requestRandomnessForRound() to capture the event data
     * @param consumer The MegaPot contract address
     * @param round The drand round from the event
     * @param data The encoded data from the event (contains requestId and extraData)
     */
    function captureRequest(
        address consumer,
        uint256 round,
        bytes calldata data
    ) external {
        // Decode to get requestId
        (uint256 requestId, ) = abi.decode(data, (uint256, bytes));
        
        // Store the full dataWithRound
        bytes memory dataWithRound = abi.encode(round, data);
        requestDataByConsumer[consumer][requestId] = dataWithRound;
        lastRequestId[consumer] = requestId;

        emit RequestDataCaptured(consumer, requestId, round, data);
    }

    /**
     * @notice Fulfill randomness using captured request data
     * @dev Uses the exact dataWithRound that was stored during request
     * @param consumer The MegaPot contract address
     * @param randomness The random value to provide
     * @param requestId The request ID to fulfill
     */
    function fulfillRandomness(
        address consumer,
        uint256 randomness,
        uint256 requestId
    ) external {
        bytes memory dataWithRound = requestDataByConsumer[consumer][requestId];
        require(dataWithRound.length > 0, "Request not captured");

        // Clear the stored data
        delete requestDataByConsumer[consumer][requestId];

        // Call fulfillRandomness on the consumer with exact data
        GelatoVRFConsumerBase(consumer).fulfillRandomness(randomness, dataWithRound);
    }

    /**
     * @notice Convenience function to fulfill the last request
     * @param consumer The MegaPot contract address
     * @param randomness The random value to provide
     */
    function fulfillLastRequest(
        address consumer,
        uint256 randomness
    ) external {
        uint256 requestId = lastRequestId[consumer];
        bytes memory dataWithRound = requestDataByConsumer[consumer][requestId];
        require(dataWithRound.length > 0, "Request not captured");

        // Clear the stored data
        delete requestDataByConsumer[consumer][requestId];

        // Call fulfillRandomness on the consumer
        GelatoVRFConsumerBase(consumer).fulfillRandomness(randomness, dataWithRound);
    }
}
