# MegaPot Smart Contracts

Decentralized number guessing game built on MegaETH with Gelato VRF for provably fair randomness.

## Overview

MegaPot is a lottery-style game where players purchase numbers from 0000-9999. At the end of each round, a verifiably random number is drawn using Gelato VRF (powered by Drand). Winners split the pot; if no winner, the entire pot rolls over to create progressively larger jackpots.

**Key Features:**
- ERC-20 token (USDm) for ticket purchases and payouts
- Gelato VRF for tamper-proof randomness (free on testnet!)
- Configurable round duration, platform fee, and number price
- Parameter changes only take effect on next round (never mid-round)
- Full event emission for transparency and on-chain audit trail

## Contract Architecture

```
packages/contracts/
├── src/
│   ├── MegaPot.sol              # Main game contract (inherits GelatoVRFConsumerBase)
│   └── USDm.sol                 # Mock stablecoin (testnet only)
├── script/
│   ├── DeployUSDm.s.sol         # USDm deployment script
│   └── DeployMegaPot.s.sol      # MegaPot deployment script
└── test/
    ├── MegaPot.t.sol            # MegaPot tests
    ├── USDm.t.sol               # USDm tests
    └── mocks/
        └── MockVRFCoordinator.sol   # Gelato VRF mock for testing
```

### MegaPot.sol

The main game contract that handles:
- Round lifecycle management
- Number purchases with ERC-20 tokens
- VRF randomness requests and fulfillment via Gelato
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
- Access to MegaETH RPC (`https://carrot.megaeth.com/rpc`)
- Testnet ETH from [MegaETH Faucet](https://testnet.megaeth.com/)

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
  --rpc-url https://carrot.megaeth.com/rpc \
  --broadcast
```

### 2. Deploy MegaPot

```bash
# Required environment variables
export DEPLOYER_PRIVATE_KEY=0x...
export GELATO_OPERATOR=0x...           # Gelato VRF operator (see step 3)
export USDM_ADDRESS=0x...              # USDm token address from step 1

# Optional environment variables (with defaults)
export ROUND_DURATION=300              # Round duration in seconds (5 min)
export PLATFORM_FEE_BPS=500            # Platform fee in basis points (5%)
export NUMBER_PRICE=1000000            # Price per number in USDm (6 decimals = $1)

# Deploy to MegaETH
forge script script/DeployMegaPot.s.sol \
  --rpc-url https://carrot.megaeth.com/rpc \
  --broadcast
```

**Note:** For initial deployment, you can use a placeholder address for `GELATO_OPERATOR`. After creating the Gelato VRF task (step 3), call `setOperator()` to update it.

### 3. Set Up Gelato VRF

After deploying MegaPot, create a Gelato VRF task:

1. Go to [Gelato App](https://app.gelato.network/)
2. Connect your wallet to MegaETH Testnet (Chain ID: 6342)
3. Create a new VRF task:
   - Select "VRF" service
   - Enter your MegaPot contract address
   - Gelato will auto-listen for `RequestedRandomness` events
4. Note the **dedicated msg.sender** (operator address) from the dashboard
5. Call `setOperator(operatorAddress)` on your MegaPot contract

**Why Gelato VRF?**
- Free on testnet (Gelato subsidizes transactions)
- Supports MegaETH Timothy Testnet
- Simple event-based integration (no subscription management)
- Powered by Drand for verifiable randomness

See [Gelato VRF Docs](https://docs.gelato.network/web3-services/vrf) for more details.

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

### Updating Gelato Operator

If the Gelato operator address changes:

```solidity
// Update the Gelato VRF operator address
megaPot.setOperator(newOperatorAddress);
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
| `RoundRandomnessRequested` | VRF request submitted to Gelato |
| `RoundSettled` | Round ends with winner info and payout details |
| `ConfigQueued` | Admin queued a config change |
| `ConfigApplied` | Queued config applied to new round |
| `FeesWithdrawn` | Platform fees withdrawn |
| `OperatorUpdated` | Gelato operator address changed |

### VRF Troubleshooting

If VRF requests are pending for too long:

1. Check your Gelato VRF task is active at [app.gelato.network](https://app.gelato.network/)
2. Verify MegaPot contract address matches the task
3. Check Gelato has sufficient balance (free on testnet)
4. Review task execution logs in Gelato dashboard

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

Use MegaETH's [Realtime API](https://docs.megaeth.com/realtime-api) for efficient event monitoring:

```typescript
// Subscribe to MegaPot events via WebSocket
const ws = new WebSocket(MEGAETH_WS_URL);
ws.send(JSON.stringify({
  method: "eth_subscribe",
  params: ["logs", { address: MEGAPOT_ADDRESS }]
}));
```

**Note:** Some WebSocket methods are currently rate-limited on MegaETH testnet. See [MegaETH FAQ](https://docs.megaeth.com/faq) for details.

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

1. **VRF Security**: Only the Gelato operator can call `fulfillRandomness`
2. **Reentrancy**: All payout functions protected by `nonReentrant`
3. **Token Safety**: All transfers use OpenZeppelin's `SafeERC20`
4. **Access Control**: Admin functions protected by `onlyOwner`
5. **Config Safety**: Changes only apply to next round, never mid-round
6. **Timing**: 10-second buffer before round end prevents last-second issues
7. **Token Consistency**: Do not change `config.token` after deployment if fees have accrued in the current token

## MegaETH Network Details

| Parameter | Value |
|-----------|-------|
| **Network Name** | MegaETH Testnet |
| **Chain ID** | 6342 |
| **RPC URL** | `https://carrot.megaeth.com/rpc` |
| **Block Explorer** | `https://megaexplorer.xyz` |
| **Block Gas Limit** | 2,000,000,000 (2B) |
| **Faucet** | `https://testnet.megaeth.com/` |

## Gas Optimization Notes

MegaETH has a 2 billion gas block limit (66x Ethereum), so gas concerns are minimal:
- Winner payouts can handle thousands of winners in a single transaction
- No artificial caps needed on holders per number

## License

MIT
