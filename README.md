# Solidity Escrow Smart Contract

A production-ready escrow smart contract built with Solidity ^0.8.20 and Foundry.

## What’s included

- `src/Escrow.sol` — main escrow contract
- `test/Escrow.t.sol` — core unit tests (constructor + create deal)
- `test/EscrowLifecycle.t.sol` — complete lifecycle and edge-case tests
- `foundry.toml` — Foundry configuration

## Contract behavior

- Buyer creates a deal and deposits ETH
- Seller receives settled amount on confirmation
- Platform receives fee (basis points, max < 10000)
- Refund path exists before completion
- ReentrancyGuard + custom errors for safety and gas efficiency

## Test file separation (your request)

- `test/Escrow.t.sol`: basic flow only
- `test/EscrowLifecycle.t.sol`: deposit, confirmation, refund, withdrawal, invalid pathways, multiple deals

This is preferred for readability and modular test maintenance.

## Setup (Foundry)

1. Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Clone + install:

```bash
git clone <repository-url>
cd solidiy-escrow
forge install
```

3. Build + test:

```bash
forge build
forge test
```

## Running tests (local)

```bash
forge test
```

- Specific test: `forge test --match-test testFullEscrowLifecycle`
- Gas report: `forge test --gas-report`
- Coverage: `forge coverage`

## 🌐 Deploy to Sepolia

1. Export environment variables:

```bash
export SEPOLIA_RPC="https://sepolia.infura.io/v3/<INFURA_KEY>"
export PRIVATE_KEY="0x..."
```

2. (Optional) add to `foundry.toml`:

```toml
[rpc_endpoints]
sepolia = "${SEPOLIA_RPC}"
```

3. Deploy contract:

```bash
forge create --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY \
  src/Escrow.sol:Escrow \
  --constructor-args 0xYourPlatformAddress 200
```

4. Verify on chain:

```bash
cast tx $SEPOLIA_RPC <txhash> --json
cast balance <contract-address> --rpc-url $SEPOLIA_RPC
```

## Contract API

- `createDeal(address seller, uint256 amount)`
- `deposit(uint256 dealId)`
- `confirmDelivery(uint256 dealId)`
- `refund(uint256 dealId)`
- `withdrawPlatformFees()`
- `updatePlatformFee(uint256 _platformFee)`
- `getDealStatus(uint256 dealId)`
- `getDeal(uint256 dealId)`

## Platform Fee

- 200 = 2%
- 500 = 5%
- 1000 = 10%

Example 1 ETH deal at 2%:
- seller receives 0.98 ETH
- platform receives 0.02 ETH

## Notes

- `Escrow` uses `ReentrancyGuard` to prevent reentrancy
- Fee requires `< 10000` (non-inclusive), so 100% is disallowed
- Refund and confirm flows are mutually exclusive

## License

- MIT

