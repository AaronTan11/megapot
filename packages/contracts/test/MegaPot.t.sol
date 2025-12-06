// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {MegaPot} from "../src/MegaPot.sol";
import {USDm} from "../src/USDm.sol";
import {MockGelatoOperator} from "./mocks/MockVRFCoordinator.sol";

/**
 * @title MegaPotTest
 * @notice Comprehensive tests for MegaPot game contract with Gelato VRF
 */
contract MegaPotTest is Test {
    MegaPot public megaPot;
    USDm public token;
    MockGelatoOperator public gelatoOperator;

    address public owner;
    address public alice;
    address public bob;
    address public charlie;

    // Game configuration
    uint256 public constant ROUND_DURATION = 300; // 5 minutes
    uint256 public constant PLATFORM_FEE_BPS = 500; // 5%
    uint256 public constant NUMBER_PRICE = 1_000_000; // $1 (6 decimals)

    // Betting close buffer
    uint256 public constant BETTING_CLOSE_BUFFER = 10;

    // Use realistic timestamp for Gelato VRF (genesis is 1692803367)
    uint256 public constant START_TIMESTAMP = 1700000000; // Nov 2023

    function setUp() public {
        // Warp to realistic timestamp before any operations
        vm.warp(START_TIMESTAMP);
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Deploy mock Gelato operator
        gelatoOperator = new MockGelatoOperator();

        // Deploy USDm token
        vm.prank(owner);
        token = new USDm(owner);

        // Create initial config
        MegaPot.RoundConfig memory config = MegaPot.RoundConfig({
            roundDuration: ROUND_DURATION,
            platformFeeBps: PLATFORM_FEE_BPS,
            numberPrice: NUMBER_PRICE,
            token: IERC20(address(token))
        });

        // Deploy MegaPot with Gelato VRF
        vm.prank(owner);
        megaPot = new MegaPot(
            owner,
            address(gelatoOperator),
            config
        );

        // Mint tokens to players
        vm.startPrank(owner);
        token.mint(alice, 100_000 * 1e6);
        token.mint(bob, 100_000 * 1e6);
        token.mint(charlie, 100_000 * 1e6);
        vm.stopPrank();

        // Approve MegaPot to spend tokens
        vm.prank(alice);
        token.approve(address(megaPot), type(uint256).max);
        vm.prank(bob);
        token.approve(address(megaPot), type(uint256).max);
        vm.prank(charlie);
        token.approve(address(megaPot), type(uint256).max);
    }

    // ============ Constructor Tests ============

    function test_Constructor_InitializesCorrectly() public view {
        assertEq(megaPot.owner(), owner);
        assertEq(megaPot.gelatoOperator(), address(gelatoOperator));
        assertEq(megaPot.currentRoundId(), 1);
    }

    function test_Constructor_StartsFirstRound() public view {
        MegaPot.Round memory round = megaPot.getCurrentRound();
        assertEq(round.id, 1);
        assertEq(round.pot, 0);
        assertEq(round.rollover, 0);
        assertFalse(round.settled);
        assertFalse(round.randomnessRequested);
    }

    function test_RevertWhen_Constructor_InvalidOperator() public {
        MegaPot.RoundConfig memory config = MegaPot.RoundConfig({
            roundDuration: ROUND_DURATION,
            platformFeeBps: PLATFORM_FEE_BPS,
            numberPrice: NUMBER_PRICE,
            token: IERC20(address(token))
        });

        vm.expectRevert(MegaPot.InvalidOperator.selector);
        new MegaPot(
            owner,
            address(0), // Invalid operator
            config
        );
    }

    function test_RevertWhen_Constructor_InvalidRoundDuration() public {
        MegaPot.RoundConfig memory config = MegaPot.RoundConfig({
            roundDuration: 30, // Too short (< MIN_ROUND_DURATION)
            platformFeeBps: PLATFORM_FEE_BPS,
            numberPrice: NUMBER_PRICE,
            token: IERC20(address(token))
        });

        vm.expectRevert(MegaPot.InvalidRoundDuration.selector);
        new MegaPot(owner, address(gelatoOperator), config);
    }

    function test_RevertWhen_Constructor_InvalidPlatformFee() public {
        MegaPot.RoundConfig memory config = MegaPot.RoundConfig({
            roundDuration: ROUND_DURATION,
            platformFeeBps: 3000, // Too high (> MAX_PLATFORM_FEE_BPS)
            numberPrice: NUMBER_PRICE,
            token: IERC20(address(token))
        });

        vm.expectRevert(MegaPot.InvalidPlatformFee.selector);
        new MegaPot(owner, address(gelatoOperator), config);
    }

    function test_RevertWhen_Constructor_InvalidNumberPrice() public {
        MegaPot.RoundConfig memory config = MegaPot.RoundConfig({
            roundDuration: ROUND_DURATION,
            platformFeeBps: PLATFORM_FEE_BPS,
            numberPrice: 0, // Invalid
            token: IERC20(address(token))
        });

        vm.expectRevert(MegaPot.InvalidNumberPrice.selector);
        new MegaPot(owner, address(gelatoOperator), config);
    }

    function test_RevertWhen_Constructor_InvalidToken() public {
        MegaPot.RoundConfig memory config = MegaPot.RoundConfig({
            roundDuration: ROUND_DURATION,
            platformFeeBps: PLATFORM_FEE_BPS,
            numberPrice: NUMBER_PRICE,
            token: IERC20(address(0)) // Invalid
        });

        vm.expectRevert(MegaPot.InvalidToken.selector);
        new MegaPot(owner, address(gelatoOperator), config);
    }

    // ============ Buy Number Tests ============

    function test_BuyNumber_Success() public {
        vm.prank(alice);
        megaPot.buyNumber(1234);

        MegaPot.Round memory round = megaPot.getCurrentRound();
        assertEq(round.pot, NUMBER_PRICE);
        assertEq(megaPot.getEntryCount(1), 1);

        address[] memory holders = megaPot.getHolders(1, 1234);
        assertEq(holders.length, 1);
        assertEq(holders[0], alice);
    }

    function test_BuyNumber_MultipleNumbers() public {
        vm.startPrank(alice);
        megaPot.buyNumber(1234);
        megaPot.buyNumber(5678);
        megaPot.buyNumber(9999);
        vm.stopPrank();

        MegaPot.Round memory round = megaPot.getCurrentRound();
        assertEq(round.pot, NUMBER_PRICE * 3);
        assertEq(megaPot.getEntryCount(1), 3);
    }

    function test_BuyNumber_SameNumberMultipleTimes() public {
        vm.prank(alice);
        megaPot.buyNumber(1234);

        vm.prank(bob);
        megaPot.buyNumber(1234);

        address[] memory holders = megaPot.getHolders(1, 1234);
        assertEq(holders.length, 2);
        assertEq(holders[0], alice);
        assertEq(holders[1], bob);
    }

    function test_BuyNumber_MaxNumber() public {
        vm.prank(alice);
        megaPot.buyNumber(9999);

        address[] memory holders = megaPot.getHolders(1, 9999);
        assertEq(holders.length, 1);
    }

    function test_BuyNumber_MinNumber() public {
        vm.prank(alice);
        megaPot.buyNumber(0);

        address[] memory holders = megaPot.getHolders(1, 0);
        assertEq(holders.length, 1);
    }

    function test_RevertWhen_BuyNumber_InvalidNumber() public {
        vm.prank(alice);
        vm.expectRevert(MegaPot.InvalidNumber.selector);
        megaPot.buyNumber(10000);
    }

    function test_RevertWhen_BuyNumber_BettingClosed() public {
        // Warp to 5 seconds before round end (within 10 second buffer)
        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime - 5);

        vm.prank(alice);
        vm.expectRevert(MegaPot.BettingClosed.selector);
        megaPot.buyNumber(1234);
    }

    function test_BuyNumber_JustBeforeClose() public {
        // Warp to exactly 11 seconds before round end (should work)
        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime - 11);

        vm.prank(alice);
        megaPot.buyNumber(1234);

        assertEq(megaPot.getEntryCount(1), 1);
    }

    function testFuzz_BuyNumber(uint16 number) public {
        vm.assume(number <= 9999);

        vm.prank(alice);
        megaPot.buyNumber(number);

        address[] memory holders = megaPot.getHolders(1, number);
        assertEq(holders.length, 1);
        assertEq(holders[0], alice);
    }

    // ============ Round Resolution Tests ============

    function test_RequestRandomness_Success() public {
        // Buy a number
        vm.prank(alice);
        megaPot.buyNumber(1234);

        // Warp past round end
        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime + 1);

        // Request randomness
        megaPot.requestRandomnessForRound();

        round = megaPot.getCurrentRound();
        assertTrue(round.randomnessRequested);
        assertEq(round.vrfRequestId, 0); // First request ID is 0
    }

    function test_RevertWhen_RequestRandomness_RoundNotEnded() public {
        vm.expectRevert(MegaPot.RoundNotEnded.selector);
        megaPot.requestRandomnessForRound();
    }

    function test_RevertWhen_RequestRandomness_AlreadyRequested() public {
        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime + 1);

        megaPot.requestRandomnessForRound();

        vm.expectRevert(MegaPot.RandomnessAlreadyRequested.selector);
        megaPot.requestRandomnessForRound();
    }

    // ============ Settlement Tests ============

    function test_Settlement_SingleWinner() public {
        // Alice buys number 1234
        vm.prank(alice);
        megaPot.buyNumber(1234);

        uint256 aliceBalanceBefore = token.balanceOf(alice);

        // Warp and request randomness
        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime + 1);
        megaPot.requestRandomnessForRound();

        // Fulfill with winning number 1234
        // Random value that produces 1234 when mod 10000
        uint256 randomValue = 1234;
        vm.prank(address(gelatoOperator));
        gelatoOperator.fulfillRandomnessForRound(
            address(megaPot),
            randomValue,
            0, // requestId (first request)
            1  // roundId
        );

        // Check Alice received winnings (pot - 5% fee)
        uint256 expectedPayout = NUMBER_PRICE * 95 / 100;
        assertEq(token.balanceOf(alice) - aliceBalanceBefore, expectedPayout);

        // Check fees accrued
        assertEq(megaPot.accruedFees(), NUMBER_PRICE * 5 / 100);

        // Check new round started
        assertEq(megaPot.currentRoundId(), 2);
    }

    function test_Settlement_MultipleWinners() public {
        // Alice and Bob both buy number 5000
        vm.prank(alice);
        megaPot.buyNumber(5000);
        vm.prank(bob);
        megaPot.buyNumber(5000);

        uint256 totalPot = NUMBER_PRICE * 2;
        uint256 aliceBalanceBefore = token.balanceOf(alice);
        uint256 bobBalanceBefore = token.balanceOf(bob);

        // Warp and request randomness
        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime + 1);
        megaPot.requestRandomnessForRound();

        // Fulfill with winning number 5000
        vm.prank(address(gelatoOperator));
        gelatoOperator.fulfillRandomnessForRound(
            address(megaPot),
            5000,
            0,
            1
        );

        // Check both received equal share (total - 5% fee) / 2
        uint256 fee = totalPot * 5 / 100;
        uint256 distributable = totalPot - fee;
        uint256 expectedPerWinner = distributable / 2;

        assertEq(token.balanceOf(alice) - aliceBalanceBefore, expectedPerWinner);
        assertEq(token.balanceOf(bob) - bobBalanceBefore, expectedPerWinner);
    }

    function test_Settlement_NoWinner_Rollover() public {
        // Alice buys number 1234
        vm.prank(alice);
        megaPot.buyNumber(1234);

        // Warp and request randomness
        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime + 1);
        megaPot.requestRandomnessForRound();

        // Fulfill with non-winning number 9999
        vm.prank(address(gelatoOperator));
        gelatoOperator.fulfillRandomnessForRound(
            address(megaPot),
            9999,
            0,
            1
        );

        // Check pot rolled over
        MegaPot.Round memory newRound = megaPot.getCurrentRound();
        assertEq(newRound.pot, NUMBER_PRICE);
        assertEq(newRound.rollover, NUMBER_PRICE);

        // No fees should be taken
        assertEq(megaPot.accruedFees(), 0);
    }

    function test_Settlement_NoParticipation() public {
        // No one buys numbers
        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime + 1);
        megaPot.requestRandomnessForRound();

        // Fulfill
        vm.prank(address(gelatoOperator));
        gelatoOperator.fulfillRandomnessForRound(
            address(megaPot),
            1234,
            0,
            1
        );

        // New round should have zero pot
        MegaPot.Round memory newRound = megaPot.getCurrentRound();
        assertEq(newRound.pot, 0);
        assertEq(newRound.rollover, 0);
    }

    function test_Settlement_LargeRollover() public {
        // Simulate multiple rounds with no winner
        for (uint256 i = 0; i < 3; i++) {
            // Multiple players buy different numbers
            vm.prank(alice);
            megaPot.buyNumber(uint16(i));
            vm.prank(bob);
            megaPot.buyNumber(uint16(i + 100));

            MegaPot.Round memory currentRound = megaPot.getCurrentRound();
            vm.warp(currentRound.endTime + 1);
            megaPot.requestRandomnessForRound();

            // Non-winning number (guaranteed not to match: 9999)
            uint256 requestId = i;
            uint256 roundId = megaPot.currentRoundId();
            vm.prank(address(gelatoOperator));
            gelatoOperator.fulfillRandomnessForRound(
                address(megaPot),
                9999, // Won't match anyone's number (0-2 and 100-102)
                requestId,
                roundId
            );
        }

        // Pot should have accumulated
        MegaPot.Round memory finalRound = megaPot.getCurrentRound();
        assertEq(finalRound.pot, NUMBER_PRICE * 6); // 2 players * 3 rounds
    }

    function testFuzz_Settlement_RandomWinner(uint256 randomWord) public {
        // Buy the winning number that will result from randomWord
        uint16 winningNumber = uint16(randomWord % 10000);

        vm.prank(alice);
        megaPot.buyNumber(winningNumber);

        uint256 aliceBalanceBefore = token.balanceOf(alice);

        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime + 1);
        megaPot.requestRandomnessForRound();

        vm.prank(address(gelatoOperator));
        gelatoOperator.fulfillRandomnessForRound(
            address(megaPot),
            randomWord,
            0,
            1
        );

        // Alice should always win
        uint256 expectedPayout = NUMBER_PRICE * 95 / 100;
        assertEq(token.balanceOf(alice) - aliceBalanceBefore, expectedPayout);
    }

    // ============ Admin Functions Tests ============

    function test_QueueConfigUpdate() public {
        MegaPot.RoundConfig memory newConfig = MegaPot.RoundConfig({
            roundDuration: 600,
            platformFeeBps: 1000,
            numberPrice: 2_000_000,
            token: IERC20(address(token))
        });

        vm.prank(owner);
        megaPot.queueConfigUpdate(newConfig);

        assertTrue(megaPot.hasPendingConfig());
    }

    function test_ConfigAppliedOnNextRound() public {
        MegaPot.RoundConfig memory newConfig = MegaPot.RoundConfig({
            roundDuration: 600,
            platformFeeBps: 1000,
            numberPrice: 2_000_000,
            token: IERC20(address(token))
        });

        vm.prank(owner);
        megaPot.queueConfigUpdate(newConfig);

        // Complete current round
        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime + 1);
        megaPot.requestRandomnessForRound();
        
        vm.prank(address(gelatoOperator));
        gelatoOperator.fulfillRandomnessForRound(address(megaPot), 1234, 0, 1);

        // Check new config applied
        (uint256 roundDuration, uint256 platformFeeBps, uint256 numberPrice, ) = megaPot.config();
        assertEq(roundDuration, 600);
        assertEq(platformFeeBps, 1000);
        assertEq(numberPrice, 2_000_000);
        assertFalse(megaPot.hasPendingConfig());
    }

    function test_SetOperator() public {
        address newOperator = makeAddr("newOperator");
        
        vm.prank(owner);
        megaPot.setOperator(newOperator);

        assertEq(megaPot.gelatoOperator(), newOperator);
    }

    function test_RevertWhen_SetOperator_InvalidAddress() public {
        vm.prank(owner);
        vm.expectRevert(MegaPot.InvalidOperator.selector);
        megaPot.setOperator(address(0));
    }

    function test_WithdrawFees() public {
        // Generate some fees
        vm.prank(alice);
        megaPot.buyNumber(1234);

        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime + 1);
        megaPot.requestRandomnessForRound();
        
        vm.prank(address(gelatoOperator));
        gelatoOperator.fulfillRandomnessForRound(address(megaPot), 1234, 0, 1);

        uint256 fees = megaPot.accruedFees();
        assertGt(fees, 0);

        // Withdraw fees
        address feeRecipient = makeAddr("feeRecipient");
        vm.prank(owner);
        megaPot.withdrawFees(feeRecipient);

        assertEq(token.balanceOf(feeRecipient), fees);
        assertEq(megaPot.accruedFees(), 0);
    }

    function test_RevertWhen_WithdrawFees_NoFees() public {
        address feeRecipient = makeAddr("feeRecipient");
        vm.prank(owner);
        vm.expectRevert(MegaPot.NoFeesToWithdraw.selector);
        megaPot.withdrawFees(feeRecipient);
    }

    function test_RevertWhen_NonOwnerCallsAdmin() public {
        MegaPot.RoundConfig memory newConfig = MegaPot.RoundConfig({
            roundDuration: 600,
            platformFeeBps: 1000,
            numberPrice: 2_000_000,
            token: IERC20(address(token))
        });

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        megaPot.queueConfigUpdate(newConfig);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        megaPot.setOperator(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        megaPot.withdrawFees(alice);
    }

    // ============ View Functions Tests ============

    function test_IsBettingOpen() public {
        assertTrue(megaPot.isBettingOpen());

        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime - 5); // Within close buffer
        assertFalse(megaPot.isBettingOpen());
    }

    function test_TimeUntilBettingCloses() public {
        MegaPot.Round memory round = megaPot.getCurrentRound();
        uint256 expectedTime = round.endTime - BETTING_CLOSE_BUFFER - block.timestamp;
        assertEq(megaPot.timeUntilBettingCloses(), expectedTime);

        vm.warp(round.endTime);
        assertEq(megaPot.timeUntilBettingCloses(), 0);
    }

    function test_TimeUntilRoundEnds() public {
        MegaPot.Round memory round = megaPot.getCurrentRound();
        uint256 expectedTime = round.endTime - block.timestamp;
        assertEq(megaPot.timeUntilRoundEnds(), expectedTime);

        vm.warp(round.endTime + 100);
        assertEq(megaPot.timeUntilRoundEnds(), 0);
    }

    function test_GetEntries() public {
        vm.prank(alice);
        megaPot.buyNumber(1234);
        vm.prank(bob);
        megaPot.buyNumber(5678);

        MegaPot.Entry[] memory roundEntries = megaPot.getEntries(1);
        assertEq(roundEntries.length, 2);
        assertEq(roundEntries[0].player, alice);
        assertEq(roundEntries[0].number, 1234);
        assertEq(roundEntries[1].player, bob);
        assertEq(roundEntries[1].number, 5678);
    }

    // ============ VRF Security Tests ============

    function test_RevertWhen_FulfillFromNonOperator() public {
        vm.prank(alice);
        megaPot.buyNumber(1234);

        MegaPot.Round memory round = megaPot.getCurrentRound();
        vm.warp(round.endTime + 1);
        megaPot.requestRandomnessForRound();

        // Try to fulfill from non-operator address
        bytes memory extraData = abi.encode(uint256(1));
        bytes memory innerData = abi.encode(uint256(0), extraData);
        bytes memory dataWithRound = abi.encode(block.timestamp, innerData);

        vm.prank(alice);
        vm.expectRevert("only operator");
        megaPot.fulfillRandomness(1234, dataWithRound);
    }
}

/**
 * @title MegaPotInvariantTest
 * @notice Invariant tests for MegaPot with Gelato VRF
 */
contract MegaPotInvariantTest is Test {
    MegaPot public megaPot;
    USDm public token;
    MockGelatoOperator public gelatoOperator;
    MegaPotHandler public handler;

    // Use realistic timestamp for Gelato VRF (genesis is 1692803367)
    uint256 public constant START_TIMESTAMP = 1700000000; // Nov 2023

    function setUp() public {
        // Warp to realistic timestamp
        vm.warp(START_TIMESTAMP);
        
        address owner = makeAddr("owner");

        gelatoOperator = new MockGelatoOperator();

        vm.prank(owner);
        token = new USDm(owner);

        MegaPot.RoundConfig memory config = MegaPot.RoundConfig({
            roundDuration: 300,
            platformFeeBps: 500,
            numberPrice: 1_000_000,
            token: IERC20(address(token))
        });

        vm.prank(owner);
        megaPot = new MegaPot(
            owner,
            address(gelatoOperator),
            config
        );

        handler = new MegaPotHandler(megaPot, token, gelatoOperator, owner);

        // Mint tokens to handler
        vm.prank(owner);
        token.mint(address(handler), 1_000_000_000 * 1e6);

        targetContract(address(handler));
    }

    /// @notice Token balance of MegaPot should equal pot + accrued fees
    function invariant_TokenBalanceMatchesPotPlusFees() public view {
        MegaPot.Round memory round = megaPot.getCurrentRound();
        uint256 expectedBalance = round.pot + megaPot.accruedFees();
        uint256 actualBalance = token.balanceOf(address(megaPot));

        // Allow for small dust from integer division
        assertLe(actualBalance - expectedBalance, 10);
    }

    /// @notice Round ID should always be positive
    function invariant_RoundIdPositive() public view {
        assertGt(megaPot.currentRoundId(), 0);
    }

    /// @notice Platform fee should never exceed max
    function invariant_PlatformFeeWithinBounds() public view {
        (, uint256 platformFeeBps, , ) = megaPot.config();
        assertLe(platformFeeBps, megaPot.MAX_PLATFORM_FEE_BPS());
    }
}

/**
 * @title MegaPotHandler
 * @notice Handler for invariant testing with Gelato VRF
 */
contract MegaPotHandler is Test {
    MegaPot public megaPot;
    USDm public token;
    MockGelatoOperator public gelatoOperator;
    address public owner;

    uint256 public buyCount;
    uint256 public settleCount;
    uint256 public currentRequestId;

    constructor(
        MegaPot _megaPot,
        USDm _token,
        MockGelatoOperator _gelatoOperator,
        address _owner
    ) {
        megaPot = _megaPot;
        token = _token;
        gelatoOperator = _gelatoOperator;
        owner = _owner;

        token.approve(address(megaPot), type(uint256).max);
    }

    function buyNumber(uint16 number) external {
        number = uint16(bound(number, 0, 9999));

        if (!megaPot.isBettingOpen()) return;

        megaPot.buyNumber(number);
        buyCount++;
    }

    function settleRound(uint256 randomWord) external {
        MegaPot.Round memory round = megaPot.getCurrentRound();

        if (block.timestamp < round.endTime) {
            vm.warp(round.endTime + 1);
        }

        if (round.randomnessRequested || round.settled) return;

        megaPot.requestRandomnessForRound();
        
        uint256 roundId = megaPot.currentRoundId();
        vm.prank(address(gelatoOperator));
        gelatoOperator.fulfillRandomnessForRound(
            address(megaPot),
            randomWord,
            currentRequestId,
            roundId
        );
        
        currentRequestId++;
        settleCount++;
    }
}
