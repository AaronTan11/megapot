# MegaPot Smart Contracts

Decentralized number guessing game built on MegaETH with Chainlink VRF v2.5 for provably fair randomness.

## Overview

MegaPot is a lottery-style game where players purchase numbers from 0000-9999. At the end of each round, a verifiably random number is drawn using Chainlink VRF. Winners split the pot; if no winner, the entire pot rolls over to create progressively larger jackpots.

**Key Features:**
- ERC-20 token (USDm) for ticket purchases and payouts
- Chainlink VRF v2.5 for tamper-proof randomness
- Configurable round duration, platform fee, and number price
- Parameter changes only take effect on next round (never mid-round)
- Full event emission for transparency and on-chain audit trail

## Contract Architecture

```
packages/contracts/
├── src/
│   ├── MegaPot.sol              # Main game contract
│   ├── USDm.sol                 # Mock stablecoin (testnet only)
│   └── interfaces/
│       └── IVRFCoordinatorV2_5.sol  # VRF interface
├── script/
│   ├── DeployUSDm.s.sol         # USDm deployment script
│   └── DeployMegaPot.s.sol      # MegaPot deployment script
└── test/
    ├── MegaPot.t.sol            # MegaPot tests
    ├── USDm.t.sol               # USDm tests
    └── mocks/
        └── MockVRFCoordinator.sol   # VRF mock for testing
```

### MegaPot.sol

The main game contract that handles:
- Round lifecycle management
- Number purchases with ERC-20 tokens
- VRF randomness requests and fulfillment
- Winner determination and payout distribution
- Platform fee collection
- Admin configuration updates

**Security Features (all from OpenZeppelin):**
- `Ownable` - Admin access control
- `ReentrancyGuard` - Protection against reentrancy attacks
- `SafeERC20` - Safe token transfers

### USDm.sol

Mock stablecoin simulating MegaETH's native USDm (developed with Ethena). For testnet/local development only.

**Features:**
- 6 decimals (same as USDC)
- Mintable by owner (for faucet/testing)
- Burnable by holders
- EIP-2612 permit support

## Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- Access to MegaETH RPC
- Chainlink VRF v2.5 subscription (for mainnet/testnet)

## Installation

```bash
cd packages/contracts

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

## Deployment

### 1. Deploy Mock USDm (Testnet Only)

For local/testnet development, deploy the mock USDm token:

```bash
# Set environment variables
export DEPLOYER_PRIVATE_KEY=0x...
export INITIAL_MINT_AMOUNT=1000000000000  # 1M tokens (6 decimals)

# Deploy to MegaETH testnet
forge script script/DeployUSDm.s.sol \
  --rpc-url $MEGAETH_RPC_URL \
  --broadcast
```

### 2. Set Up Chainlink VRF Subscription

Before deploying MegaPot, you need a Chainlink VRF v2.5 subscription:

1. Go to [Chainlink VRF Subscription Manager](https://vrf.chain.link/)
2. Connect your wallet
3. Create a new subscription
4. Fund the subscription with LINK tokens
5. Note down:
   - **Subscription ID**
   - **VRF Coordinator address** (network-specific)
   - **Key Hash** (gas lane, network-specific)

For network-specific values, see [Chainlink VRF Supported Networks](https://docs.chain.link/vrf/v2-5/supported-networks).

### 3. Deploy MegaPot

```bash
# Required environment variables
export DEPLOYER_PRIVATE_KEY=0x...
export VRF_COORDINATOR=0x...          # Chainlink VRF Coordinator address
export VRF_KEY_HASH=0x...             # VRF key hash (gas lane)
export VRF_SUBSCRIPTION_ID=123        # Your VRF subscription ID
export USDM_ADDRESS=0x...             # USDm token address

# Optional environment variables (with defaults)
export VRF_MIN_CONFIRMATIONS=3        # Min block confirmations (1-200)
export VRF_CALLBACK_GAS_LIMIT=500000  # Callback gas limit (100k-2.5M)
export ROUND_DURATION=300             # Round duration in seconds (5 min)
export PLATFORM_FEE_BPS=500           # Platform fee in basis points (5%)
export NUMBER_PRICE=1000000           # Price per number in USDm (6 decimals = $1)

# Deploy to MegaETH
forge script script/DeployMegaPot.s.sol \
  --rpc-url $MEGAETH_RPC_URL \
  --broadcast
```

### 4. Add MegaPot as VRF Consumer

After deployment, add MegaPot as a consumer to your VRF subscription:

1. Go to [Chainlink VRF Subscription Manager](https://vrf.chain.link/)
2. Select your subscription
3. Click "Add Consumer"
4. Enter the MegaPot contract address
5. Confirm the transaction

## Operator Runbook

### Adjusting Game Parameters

Parameters can be queued for the next round (never takes effect mid-round):

```solidity
// Queue new configuration
MegaPot.RoundConfig memory newConfig = MegaPot.RoundConfig({
    roundDuration: 600,        // 10 minutes
    platformFeeBps: 1000,      // 10%
    numberPrice: 2_000_000,    // $2
    token: IERC20(usdmAddress)
});

megaPot.queueConfigUpdate(newConfig);
```

### Updating VRF Parameters

```solidity
// Update VRF min confirmations and callback gas limit
megaPot.setVRFParams(
    5,        // minConfirmations (1-200)
    750_000   // callbackGasLimit (100k-2.5M)
);
```

### Withdrawing Platform Fees

```solidity
// Withdraw accumulated fees to a specified address
megaPot.withdrawFees(feeRecipientAddress);
```

### Monitoring

Key events to monitor:

| Event | Description |
|-------|-------------|
| `RoundStarted` | New round begins with timing and config snapshot |
| `NumberPurchased` | Player buys a number |
| `RoundRandomnessRequested` | VRF request submitted |
| `RoundSettled` | Round ends with winner info and payout details |
| `ConfigQueued` | Admin queued a config change |
| `ConfigApplied` | Queued config applied to new round |
| `FeesWithdrawn` | Platform fees withdrawn |

### VRF Troubleshooting

If VRF requests are pending for too long (>24h is failure threshold):

1. Check subscription balance has enough LINK
2. Verify MegaPot is added as consumer
3. Check callback gas limit is sufficient
4. Review [VRF Subscription Manager](https://vrf.chain.link/) for request status

## Off-Chain Resolver Service

An off-chain service is required to trigger round settlement:

### Responsibilities

1. **Monitor round timing**: Watch `RoundStarted` events for `endTime`
2. **Trigger settlement**: Call `requestRandomnessForRound()` after `endTime`
3. **Monitor VRF**: Watch for fulfillment or failures

### Implementation Example

```typescript
// Pseudo-code for off-chain resolver
async function monitorRounds() {
  const round = await megaPot.getCurrentRound();
  
  if (Date.now() / 1000 >= round.endTime) {
    if (!round.randomnessRequested && !round.settled) {
      await megaPot.requestRandomnessForRound();
    }
  }
}

// Run every few seconds
setInterval(monitorRounds, 5000);
```

### MegaETH Realtime API

Use MegaETH's [Realtime API](https://docs.megaeth.com/realtime-api.html) for efficient event monitoring:

```typescript
// Subscribe to MegaPot events via WebSocket
const ws = new WebSocket(MEGAETH_WS_URL);
ws.send(JSON.stringify({
  method: "eth_subscribe",
  params: ["logs", { address: MEGAPOT_ADDRESS }]
}));
```

## Frontend Integration

### Contract Bindings

Generate TypeScript bindings from the ABI:

```bash
# Build to generate ABI
forge build

# ABI location
cat out/MegaPot.sol/MegaPot.json | jq '.abi'
```

### Key Functions for Frontend

```typescript
// Read current round info
const round = await megaPot.getCurrentRound();
const isBettingOpen = await megaPot.isBettingOpen();
const timeLeft = await megaPot.timeUntilBettingCloses();

// Buy a number (requires prior approval)
await token.approve(megaPotAddress, numberPrice);
await megaPot.buyNumber(1234);

// Get holders of a number
const holders = await megaPot.getHolders(roundId, 1234);
```

### Real-Time Updates

Subscribe to events for live updates:

| Event | UI Update |
|-------|-----------|
| `NumberPurchased` | Update pot size, entry count |
| `RoundSettled` | Show winner, reset timer |
| `RoundStarted` | Start new round timer |

## Testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test test_Settlement_SingleWinner

# Run fuzz tests with more runs
forge test --fuzz-runs 1000

# Gas report
forge test --gas-report
```

## Security Considerations

1. **VRF Security**: Only the VRF Coordinator can call `fulfillRandomWords`
2. **Reentrancy**: All payout functions protected by `nonReentrant`
3. **Token Safety**: All transfers use OpenZeppelin's `SafeERC20`
4. **Access Control**: Admin functions protected by `onlyOwner`
5. **Config Safety**: Changes only apply to next round, never mid-round
6. **Timing**: 10-second buffer before round end prevents last-second issues

## Gas Optimization Notes

- `callbackGasLimit` should be tuned based on expected max winners per round
- For rounds with many winners of same number, callback may consume more gas
- Consider UX to discourage excessive duplication of single numbers

## License

MIT
