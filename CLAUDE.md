# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

The Ethereum Follow Protocol (EFP) ListRecordsV2 repository contains updated smart contracts for EFP's list minting and record management system. This is a Solidity project using the Foundry framework for smart contract development, with TypeScript tooling for ABI generation and testing.

## Common Commands

### Build and Development
- `bun run build` - Compiles smart contracts using Foundry
- `bun run test` - Runs all tests using Foundry with forked environment (`--fork-url ${ETH_RPC_URL} -vv`)
- `bun run coverage` - Generates test coverage report and lcov file
- `forge test --match-path test/specific.t.sol` - Run specific test file
- `forge test --match-test testFunctionName` - Run specific test function

### Deployment
- `bun run deploy` - Deploy to mainnet using `${ETH_RPC_URL}`
- `bun run deploy:testnet` - Deploy to testnet using `${TESTNET_RPC_URL}`  
- `bun run deploy:local` - Deploy to local anvil instance
- `bun run testnet` - Start local anvil fork on chain ID 8453

### ABI Generation
- `bun wagmi generate` - Generate TypeScript ABIs, actions, and React hooks from compiled contracts

## Architecture Overview

### Core Contracts

**EFPListRecordsV2** (`src/EFPListRecordsV2.sol`): The main list records contract that stores and manages list operations and metadata. Key features:
- **Slot-based access control**: Uses first 20 bytes of slot to match message sender address, preventing front-running of slot claims
- **List operations storage**: Maintains a history of operations applied to each list
- **Metadata management**: Key-value store for list metadata with manager-only access
- **Manager system**: Claims management through `onlyListManager` modifier

**EFPListMinterV2** (`src/EFPListMinterV2.sol`): Handles minting of new lists with improved validation. Key features:
- **Chain ID validation**: Ensures list records are stored on the intended chain when using native storage
- **List storage location decoding**: Validates encoded storage locations before minting
- **Primary list assignment**: Sets default lists for accounts via account metadata contract

### Contract Hierarchy

```
ListMetadata (abstract)
├── Manages metadata key-value pairs
├── Implements manager claiming and validation
└── Extends Pausable, Ownable

ListRecordsV2 (abstract)
├── Extends ListMetadata
├── Manages list operations history
└── Provides batch operations

EFPListRecordsV2 (concrete)
└── Final implementation with ENS reverse claiming
```

### Key Dependencies

- **External contracts**: Interfaces to EFPListRegistry, EFPAccountMetadata
- **OpenZeppelin**: Uses Ownable, Pausable, Context
- **ENS integration**: ENSReverseClaimer for reverse name resolution
- **Foundry libraries**: forge-std for testing and deployment

### Directory Structure

- `src/` - Main contract source files
- `src/interfaces/` - Contract interfaces
- `src/lib/` - Shared libraries (ENSReverseClaimer)
- `script/` - Deployment scripts and utilities
- `test/` - Foundry test files
- `out/` - Compiled contract artifacts
- `lib/` - Git submodules (forge-std, openzeppelin-contracts)

### Testing Approach

Tests use Foundry's testing framework with mainnet forking. Test files follow the pattern `*.t.sol` and are located in the `test/` directory. Coverage reports are generated using `forge coverage` with lcov output.

### Environment Setup

Requires `.env` file with:
- `PRIVATE_KEY` - Deployment private key
- `ETH_RPC_URL` - Mainnet RPC endpoint
- `TESTNET_RPC_URL` - Testnet RPC endpoint  
- `ETHERSCAN_API_KEY` - For contract verification

### Important Security Features

1. **Slot validation**: EFPListRecordsV2 validates that the first 20 bytes of a slot match the caller's address
2. **Chain ID checks**: EFPListMinterV2 verifies chain ID matches current chain for native storage
3. **Manager-only operations**: All list modifications require manager privileges
4. **Pausable contracts**: Admin can pause operations in emergency situations