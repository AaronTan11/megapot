// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {GelatoVRFConsumerBase} from "@gelatonetwork/GelatoVRFConsumerBase.sol";

/**
 * @title MegaPot
 * @notice Decentralized number guessing game built on MegaETH with Gelato VRF
 * @dev Players purchase numbers from 0000-9999. At round end, a verifiably random number
 *      is drawn using Gelato VRF (powered by Drand). Winners split the pot; if no winner, 
 *      pot rolls over to next round.
 *
 * Key Features:
 * - ERC-20 token (USDm) for ticket purchases and payouts
 * - Gelato VRF for provably fair randomness (free on testnet!)
 * - Configurable round duration, platform fee, and number price
 * - Parameter changes only take effect on next round (never mid-round)
 * - Full event emission for transparency and on-chain audit trail
 *
 * Security:
 * - OpenZeppelin Ownable for admin access control
 * - OpenZeppelin ReentrancyGuard for payout safety
 * - OpenZeppelin SafeERC20 for token transfer safety
 * - Gelato VRF callback restricted to operator only
 */
contract MegaPot is Ownable, ReentrancyGuard, GelatoVRFConsumerBase {
    using SafeERC20 for IERC20;

    // ============ Constants ============

    /// @notice Maximum platform fee in basis points (20%)
    uint256 public constant MAX_PLATFORM_FEE_BPS = 2000;

    /// @notice Minimum round duration in seconds (must be > betting buffer)
    uint256 public constant MIN_ROUND_DURATION = 60;

    /// @notice Betting closes this many seconds before round end
    uint256 public constant BETTING_CLOSE_BUFFER = 10;

    /// @notice Maximum number that can be purchased (0-9999)
    uint16 public constant MAX_NUMBER = 9999;

    // ============ Structs ============

    /// @notice Configuration parameters for game rounds
    struct RoundConfig {
        uint256 roundDuration;      // Duration in seconds
        uint256 platformFeeBps;     // Platform fee in basis points (1 bp = 0.01%)
        uint256 numberPrice;        // Price per number in token smallest units
        IERC20 token;               // ERC-20 token used for payments
    }

    /// @notice Data for a single game round
    struct Round {
        uint256 id;                 // Round identifier
        uint256 pot;                // Total pot for this round (including rollover)
        uint256 rollover;           // Amount rolled over from previous round
        uint256 startTime;          // Unix timestamp when round started
        uint256 endTime;            // Unix timestamp when round ends
        bool settled;               // Whether round has been settled
        uint16 winningNumber;       // Winning number (valid only if settled)
        bool randomnessRequested;   // Whether VRF request has been made
        uint256 vrfRequestId;       // Gelato VRF request ID (for audit trail)
    }

    /// @notice Entry representing a player's number purchase
    struct Entry {
        address player;
        uint16 number;
    }

    // ============ Gelato VRF Configuration ============

    /// @notice Gelato's dedicated msg.sender for VRF callbacks
    address public gelatoOperator;

    // ============ Game State ============

    /// @notice Current round configuration
    RoundConfig public config;

    /// @notice Pending configuration for next round (if any)
    RoundConfig public pendingConfig;

    /// @notice Whether there is a pending config update
    bool public hasPendingConfig;

    /// @notice Current round ID
    uint256 public currentRoundId;

    /// @notice Mapping from round ID to round data
    mapping(uint256 => Round) public rounds;

    /// @notice Mapping from round ID to list of entries
    mapping(uint256 => Entry[]) public entries;

    /// @notice Mapping from round ID => number => list of holders
    mapping(uint256 => mapping(uint16 => address[])) public holdersByNumber;

    /// @notice Mapping from VRF request ID to round ID
    mapping(uint256 => uint256) public vrfRequestIdToRoundId;

    /// @notice Accumulated platform fees (in token units)
    uint256 public accruedFees;

    // ============ Events ============

    /// @notice Emitted when a new round starts
    event RoundStarted(
        uint256 indexed roundId,
        uint256 startTime,
        uint256 endTime,
        uint256 roundDuration,
        uint256 platformFeeBps,
        uint256 numberPrice,
        address token
    );

    /// @notice Emitted when a player purchases a number
    event NumberPurchased(
        uint256 indexed roundId,
        address indexed player,
        uint16 number,
        uint256 price
    );

    /// @notice Emitted when VRF randomness is requested
    event RoundRandomnessRequested(
        uint256 indexed roundId,
        uint256 vrfRequestId
    );

    /// @notice Emitted when a round is settled
    event RoundSettled(
        uint256 indexed roundId,
        uint16 winningNumber,
        uint256 pot,
        uint256 winnersCount,
        uint256 platformFee,
        bool rollover
    );

    /// @notice Emitted when config update is queued for next round
    event ConfigQueued(
        uint256 roundDuration,
        uint256 platformFeeBps,
        uint256 numberPrice,
        address token
    );

    /// @notice Emitted when queued config is applied
    event ConfigApplied(uint256 indexed roundId);

    /// @notice Emitted when platform fees are withdrawn
    event FeesWithdrawn(address indexed to, uint256 amount);

    /// @notice Emitted when Gelato operator is updated
    event OperatorUpdated(address indexed newOperator);

    // ============ Errors ============

    error BettingClosed();
    error InvalidNumber();
    error RoundNotEnded();
    error RandomnessAlreadyRequested();
    error RoundAlreadySettled();
    error InvalidRoundDuration();
    error InvalidPlatformFee();
    error InvalidNumberPrice();
    error InvalidToken();
    error InvalidOperator();
    error NoFeesToWithdraw();
    error InvalidRoundId();

    // ============ Constructor ============

    /**
     * @notice Deploy the MegaPot contract
     * @param initialOwner Address of the contract owner/admin
     * @param _gelatoOperator Gelato's dedicated msg.sender for VRF (from Gelato dashboard)
     * @param _config Initial round configuration
     */
    constructor(
        address initialOwner,
        address _gelatoOperator,
        RoundConfig memory _config
    ) Ownable(initialOwner) {
        // Validate Gelato operator
        if (_gelatoOperator == address(0)) revert InvalidOperator();

        // Validate initial config
        _validateConfig(_config);

        // Set Gelato operator
        gelatoOperator = _gelatoOperator;

        // Set initial game config
        config = _config;

        // Start the first round
        _startRound(0);
    }

    // ============ Gelato VRF Overrides ============

    /**
     * @notice Returns the Gelato operator address
     * @dev Required by GelatoVRFConsumerBase
     * @return Address of the Gelato operator
     */
    function _operator() internal view override returns (address) {
        return gelatoOperator;
    }

    /**
     * @notice Handles the random value from Gelato VRF
     * @dev Called by GelatoVRFConsumerBase.fulfillRandomness after validation
     * @param randomness The random number from Drand
     * @param requestId The VRF request ID
     * @param extraData Encoded round ID
     */
    function _fulfillRandomness(
        uint256 randomness,
        uint256 requestId,
        bytes memory extraData
    ) internal override nonReentrant {
        // Decode round ID from extraData
        uint256 roundId = abi.decode(extraData, (uint256));
        
        // Validate round
        if (roundId == 0 || roundId > currentRoundId) revert InvalidRoundId();
        
        Round storage round = rounds[roundId];

        // Verify round state
        if (round.settled) {
            revert RoundAlreadySettled();
        }

        // Calculate winning number (0-9999)
        uint16 winningNumber = uint16(randomness % 10_000);
        round.winningNumber = winningNumber;
        round.settled = true;

        // Get winners
        address[] storage winners = holdersByNumber[roundId][winningNumber];
        uint256 winnersCount = winners.length;
        uint256 platformFee = 0;
        uint256 rolloverAmount = 0;

        if (winnersCount > 0 && round.pot > 0) {
            // Calculate platform fee
            platformFee = (round.pot * config.platformFeeBps) / 10_000;
            accruedFees += platformFee;

            // Calculate payout per winner
            uint256 distributable = round.pot - platformFee;
            uint256 payoutPerWinner = distributable / winnersCount;

            // Distribute to winners
            for (uint256 i = 0; i < winnersCount; i++) {
                config.token.safeTransfer(winners[i], payoutPerWinner);
            }

            // Handle dust (remainder from integer division)
            uint256 dust = distributable - (payoutPerWinner * winnersCount);
            if (dust > 0) {
                accruedFees += dust;
            }
        } else {
            // No winners - entire pot rolls over
            rolloverAmount = round.pot;
        }

        emit RoundSettled(
            roundId,
            winningNumber,
            round.pot,
            winnersCount,
            platformFee,
            winnersCount == 0
        );

        // Start next round with rollover
        _startRound(rolloverAmount);
    }

    // ============ Player Functions ============

    /**
     * @notice Purchase a number for the current round
     * @dev Player must have approved the contract to spend numberPrice tokens
     * @param number The number to purchase (0-9999)
     */
    function buyNumber(uint16 number) external nonReentrant {
        Round storage round = rounds[currentRoundId];

        // Check betting window is open (closes 10 seconds before round end)
        if (block.timestamp >= round.endTime - BETTING_CLOSE_BUFFER) {
            revert BettingClosed();
        }

        // Validate number
        if (number > MAX_NUMBER) {
            revert InvalidNumber();
        }

        // Transfer tokens from player to contract
        config.token.safeTransferFrom(msg.sender, address(this), config.numberPrice);

        // Update pot
        round.pot += config.numberPrice;

        // Record entry
        entries[currentRoundId].push(Entry({player: msg.sender, number: number}));
        holdersByNumber[currentRoundId][number].push(msg.sender);

        emit NumberPurchased(currentRoundId, msg.sender, number, config.numberPrice);
    }

    // ============ Round Resolution Functions ============

    /**
     * @notice Request randomness to settle the current round
     * @dev Can be called by anyone once the round has ended
     *      Off-chain keeper service typically calls this
     */
    function requestRandomnessForRound() external {
        Round storage round = rounds[currentRoundId];

        // Check round has ended
        if (block.timestamp < round.endTime) {
            revert RoundNotEnded();
        }

        // Check randomness not already requested
        if (round.randomnessRequested) {
            revert RandomnessAlreadyRequested();
        }

        // Check round not already settled
        if (round.settled) {
            revert RoundAlreadySettled();
        }

        // Encode current round ID for callback
        bytes memory extraData = abi.encode(currentRoundId);

        // Request randomness from Gelato VRF
        uint256 vrfRequestId = _requestRandomness(extraData);

        // Update state
        round.randomnessRequested = true;
        round.vrfRequestId = vrfRequestId;
        vrfRequestIdToRoundId[vrfRequestId] = currentRoundId;

        emit RoundRandomnessRequested(currentRoundId, vrfRequestId);
    }

    // ============ Admin Functions ============

    /**
     * @notice Queue a configuration update for the next round
     * @dev Changes never take effect mid-round
     * @param _config New configuration to apply at next round start
     */
    function queueConfigUpdate(RoundConfig calldata _config) external onlyOwner {
        _validateConfig(_config);

        pendingConfig = _config;
        hasPendingConfig = true;

        emit ConfigQueued(
            _config.roundDuration,
            _config.platformFeeBps,
            _config.numberPrice,
            address(_config.token)
        );
    }

    /**
     * @notice Update the Gelato operator address
     * @dev Only needed if Gelato changes their dedicated msg.sender
     * @param _newOperator New operator address from Gelato dashboard
     */
    function setOperator(address _newOperator) external onlyOwner {
        if (_newOperator == address(0)) revert InvalidOperator();
        gelatoOperator = _newOperator;
        emit OperatorUpdated(_newOperator);
    }

    /**
     * @notice Withdraw accumulated platform fees
     * @param to Address to send fees to
     */
    function withdrawFees(address to) external onlyOwner nonReentrant {
        uint256 amount = accruedFees;
        if (amount == 0) revert NoFeesToWithdraw();

        accruedFees = 0;
        config.token.safeTransfer(to, amount);

        emit FeesWithdrawn(to, amount);
    }

    // ============ View Functions ============

    /**
     * @notice Get current round data
     * @return Round struct for current round
     */
    function getCurrentRound() external view returns (Round memory) {
        return rounds[currentRoundId];
    }

    /**
     * @notice Get entries for a specific round
     * @param roundId The round ID to query
     * @return Array of Entry structs
     */
    function getEntries(uint256 roundId) external view returns (Entry[] memory) {
        return entries[roundId];
    }

    /**
     * @notice Get holders of a specific number in a round
     * @param roundId The round ID to query
     * @param number The number to query (0-9999)
     * @return Array of holder addresses
     */
    function getHolders(uint256 roundId, uint16 number) external view returns (address[] memory) {
        return holdersByNumber[roundId][number];
    }

    /**
     * @notice Get number of entries in a round
     * @param roundId The round ID to query
     * @return Number of entries
     */
    function getEntryCount(uint256 roundId) external view returns (uint256) {
        return entries[roundId].length;
    }

    /**
     * @notice Check if betting is currently open
     * @return True if betting is open, false otherwise
     */
    function isBettingOpen() external view returns (bool) {
        Round storage round = rounds[currentRoundId];
        return block.timestamp < round.endTime - BETTING_CLOSE_BUFFER;
    }

    /**
     * @notice Get time remaining until betting closes
     * @return Seconds until betting closes (0 if already closed)
     */
    function timeUntilBettingCloses() external view returns (uint256) {
        Round storage round = rounds[currentRoundId];
        uint256 closeTime = round.endTime - BETTING_CLOSE_BUFFER;
        if (block.timestamp >= closeTime) return 0;
        return closeTime - block.timestamp;
    }

    /**
     * @notice Get time remaining until round ends
     * @return Seconds until round ends (0 if already ended)
     */
    function timeUntilRoundEnds() external view returns (uint256) {
        Round storage round = rounds[currentRoundId];
        if (block.timestamp >= round.endTime) return 0;
        return round.endTime - block.timestamp;
    }

    // ============ Internal Functions ============

    /**
     * @notice Start a new round
     * @param rolloverAmount Amount to roll over from previous round
     */
    function _startRound(uint256 rolloverAmount) internal {
        // Apply pending config if any
        if (hasPendingConfig) {
            config = pendingConfig;
            hasPendingConfig = false;
            delete pendingConfig;
        }

        // Increment round ID
        currentRoundId++;

        // Create new round
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + config.roundDuration;

        rounds[currentRoundId] = Round({
            id: currentRoundId,
            pot: rolloverAmount,
            rollover: rolloverAmount,
            startTime: startTime,
            endTime: endTime,
            settled: false,
            winningNumber: 0,
            randomnessRequested: false,
            vrfRequestId: 0
        });

        emit RoundStarted(
            currentRoundId,
            startTime,
            endTime,
            config.roundDuration,
            config.platformFeeBps,
            config.numberPrice,
            address(config.token)
        );
    }

    /**
     * @notice Validate configuration parameters
     * @param _config Configuration to validate
     */
    function _validateConfig(RoundConfig memory _config) internal pure {
        if (_config.roundDuration < MIN_ROUND_DURATION) revert InvalidRoundDuration();
        if (_config.platformFeeBps > MAX_PLATFORM_FEE_BPS) revert InvalidPlatformFee();
        if (_config.numberPrice == 0) revert InvalidNumberPrice();
        if (address(_config.token) == address(0)) revert InvalidToken();
    }
}
