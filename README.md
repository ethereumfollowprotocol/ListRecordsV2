
<p align="center">
  <a href="https://ethfollow.xyz" target="_blank" rel="noopener noreferrer">
    <img width="275" src="https://docs.ethfollow.xyz/logo.png" alt="EFP logo" />
  </a>
</p>
<br />
<p align="center">
  <a href="https://pr.new/ethereumfollowprotocol/ListRecordsV2"><img src="https://developer.stackblitz.com/img/start_pr_dark_small.svg" alt="Start new PR in StackBlitz Codeflow" /></a>
  <a href="https://discord.ethfollow.xyz"><img src="https://img.shields.io/badge/chat-discord-blue?style=flat&logo=discord" alt="discord chat" /></a>
  <a href="https://x.com/efp"><img src="https://img.shields.io/twitter/follow/efp?label=%40efp&style=social&link=https%3A%2F%2Fx.com%2Fefp" alt="x account" /></a>
</p>

<h1 align="center" style="font-size: 2.75rem; font-weight: 900; color: white;">Ethereum Follow Protocol ListRecordsV2</h1>

> A native Ethereum protocol for following and tagging Ethereum accounts.

# ListRecordsV2
Updated List Records and List Minter Contracts for the Ethereum Follow Protocol. These new EFP contracts update two key parts of the list minting process: slot construction and list storage location assignment.

### Slot Construction
The updated list records contract now checks the first 20bytes of a slot to confirm that it matches the address of the message sender in the 'claimListManager' function.  This effectively prevents all other accounts from 'front-running' the claiming of a slot, as any accounts attempting to claim the slot for themselves will be blocked unless the address calling the function matches the address specified in the slot

### List Storage Location Assignment
An additional check was added to the easyMint and easyMintTo functions to ensure that list records are stored in the appropriate contract.  If a list records contract was deployed with an address that is identical to a previous deployment on another chain, a user could potentially have their list records stored in an unintended location.  This update adds a check to ensure that the chain id specified in the list storage location matches the current chain before storing the list records, if the list records are stored on the native chain (Base).

### Important links

- Documentation: [**docs.ethfollow.xyz/**](https://docs.ethfollow.xyz/)

## Getting started with development

### Prerequisites

- [Bun runtime](https://bun.sh/) (latest version)
- [Node.js](https://nodejs.org/en/) (LTS which is currently 20)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Installation

```bash
git clone https://github.com/ethereumfollowprotocol/ListRecordsV2.git && cd ListRecordsV2
```

> [!NOTE]
> If vscode extensions behave weirdly or you stop getting type hints, run CMD+P and type `> Developer: Restart Extension Host` to restart the extension host.

```bash
# upgrade bun to make sure you have the latest version then install dependencies
bun upgrade && bun install
```

### Env vars
Copy `.env-example` to `.env` and provide the values for `PRIVATE_KEY`, `ETH_RPC_URL`, `TESTNET_RPC_URL`, and `ETHERSCAN_API_KEY` 

```bash
cp .env-example .env
```

### Build
To build, run
```bash
bun run build
```

Build artifacts are stored in `out/`.

### Test
To build and test, run
```bash
bun run test
```

### Test Coverage
To generate a test coverage report and lcov.info file
```bash
bun run coverage
```

### Testnet setup
To create a new instance of anvil using the `ETH_RPC_URL` as the forked data source
```bash
bun run testnet
```

### Deploy Contracts
To deploy the contracts using the `ETH_RPC_URL` as the target chain, deployed from the public address having `PRIVATE_KEY`
```bash
bun run deploy
```
