/**
 * MegaETH RPC Test Script
 *
 * Tests basic connectivity and functionality of MegaETH Testnet RPC.
 * Run with: pnpm test:rpc
 *
 * MegaETH Testnet Details:
 * - RPC: https://carrot.megaeth.com/rpc
 * - Chain ID: 6342
 * - Block Explorer: https://megaexplorer.xyz
 * - Docs: https://docs.megaeth.com/
 */

// Try timothy testnet first, then fallback to public RPC
const MEGAETH_RPC_URL = process.env.MEGAETH_RPC_URL || "https://6342.rpc.thirdweb.com";
const EXPECTED_CHAIN_ID = 6342;

interface JsonRpcResponse<T> {
  jsonrpc: string;
  id: number;
  result?: T;
  error?: {
    code: number;
    message: string;
  };
}

async function rpcCall<T>(method: string, params: unknown[] = []): Promise<T> {
  const response = await fetch(MEGAETH_RPC_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method,
      params,
      id: Date.now(),
    }),
  });

  if (!response.ok) {
    throw new Error(`HTTP error: ${response.status} ${response.statusText}`);
  }

  const data = (await response.json()) as JsonRpcResponse<T>;

  if (data.error) {
    throw new Error(`RPC error: ${data.error.code} - ${data.error.message}`);
  }

  return data.result as T;
}

async function testChainId(): Promise<void> {
  console.log("\n🔗 Testing eth_chainId...");
  const chainIdHex = await rpcCall<string>("eth_chainId");
  const chainId = parseInt(chainIdHex, 16);

  console.log(`   Chain ID (hex): ${chainIdHex}`);
  console.log(`   Chain ID (dec): ${chainId}`);

  if (chainId === EXPECTED_CHAIN_ID) {
    console.log(`   ✅ Chain ID matches MegaETH Testnet (${EXPECTED_CHAIN_ID})`);
  } else {
    console.log(`   ⚠️ Unexpected chain ID. Expected ${EXPECTED_CHAIN_ID}, got ${chainId}`);
  }
}

async function testBlockNumber(): Promise<void> {
  console.log("\n📦 Testing eth_blockNumber...");
  const blockNumberHex = await rpcCall<string>("eth_blockNumber");
  const blockNumber = parseInt(blockNumberHex, 16);

  console.log(`   Block number (hex): ${blockNumberHex}`);
  console.log(`   Block number (dec): ${blockNumber.toLocaleString()}`);
  console.log(`   ✅ Successfully retrieved block number`);
}

async function testGasPrice(): Promise<void> {
  console.log("\n⛽ Testing eth_gasPrice...");
  const gasPriceHex = await rpcCall<string>("eth_gasPrice");
  const gasPrice = BigInt(gasPriceHex);
  const gasPriceGwei = Number(gasPrice) / 1e9;

  console.log(`   Gas price (wei): ${gasPrice.toString()}`);
  console.log(`   Gas price (gwei): ${gasPriceGwei.toFixed(4)}`);
  console.log(`   ✅ Successfully retrieved gas price`);
}

async function testLatestBlock(): Promise<void> {
  console.log("\n🧱 Testing eth_getBlockByNumber (latest)...");

  interface Block {
    number: string;
    hash: string;
    timestamp: string;
    gasLimit: string;
    gasUsed: string;
    transactions: string[];
  }

  const block = await rpcCall<Block>("eth_getBlockByNumber", ["latest", false]);

  const blockNumber = parseInt(block.number, 16);
  const timestamp = parseInt(block.timestamp, 16);
  const gasLimit = parseInt(block.gasLimit, 16);
  const gasUsed = parseInt(block.gasUsed, 16);
  const date = new Date(timestamp * 1000);

  console.log(`   Block #${blockNumber.toLocaleString()}`);
  console.log(`   Hash: ${block.hash}`);
  console.log(`   Timestamp: ${date.toISOString()}`);
  console.log(`   Gas Limit: ${gasLimit.toLocaleString()}`);
  console.log(`   Gas Used: ${gasUsed.toLocaleString()} (${((gasUsed / gasLimit) * 100).toFixed(2)}%)`);
  console.log(`   Transactions: ${block.transactions.length}`);
  console.log(`   ✅ Successfully retrieved latest block`);
}

async function testGetBalance(): Promise<void> {
  console.log("\n💰 Testing eth_getBalance (zero address)...");
  const balance = await rpcCall<string>("eth_getBalance", [
    "0x0000000000000000000000000000000000000000",
    "latest",
  ]);
  const balanceWei = BigInt(balance);
  const balanceEth = Number(balanceWei) / 1e18;

  console.log(`   Balance (wei): ${balanceWei.toString()}`);
  console.log(`   Balance (ETH): ${balanceEth.toFixed(6)}`);
  console.log(`   ✅ Successfully retrieved balance`);
}

async function testNetVersion(): Promise<void> {
  console.log("\n🌐 Testing net_version...");
  const netVersion = await rpcCall<string>("net_version");
  console.log(`   Network version: ${netVersion}`);
  console.log(`   ✅ Successfully retrieved network version`);
}

async function main(): Promise<void> {
  console.log("═══════════════════════════════════════════════════════════");
  console.log("           MegaETH Testnet RPC Connectivity Test");
  console.log("═══════════════════════════════════════════════════════════");
  console.log(`\n📡 RPC URL: ${MEGAETH_RPC_URL}`);

  const tests = [
    testChainId,
    testNetVersion,
    testBlockNumber,
    testGasPrice,
    testLatestBlock,
    testGetBalance,
  ];

  let passed = 0;
  let failed = 0;

  for (const test of tests) {
    try {
      await test();
      passed++;
    } catch (error) {
      failed++;
      console.log(`   ❌ Test failed: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  console.log("\n═══════════════════════════════════════════════════════════");
  console.log(`                    Results: ${passed}/${tests.length} passed`);
  if (failed > 0) {
    console.log(`                    ⚠️ ${failed} test(s) failed`);
  } else {
    console.log(`                    ✅ All tests passed!`);
  }
  console.log("═══════════════════════════════════════════════════════════");

  console.log("\n📝 Notes:");
  console.log("   - WebSocket methods (eth_subscribe) are currently rate-limited");
  console.log("   - See https://docs.megaeth.com/faq for details");
  console.log("   - MegaETH has 10ms mini-blocks for realtime confirmations");
  console.log("   - Block gas limit: 2,000,000,000 (2B)");
}

main().catch(console.error);

