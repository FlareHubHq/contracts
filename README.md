## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

interface IEscrowRegistry {
  enum Kind { Bounty, Contract }
  function createBountyEscrow(
    bytes32 listingId,
    address token,
    uint256 totalAmount,
    uint64 deadline,
    uint64 clawbackAfter
  ) external payable returns (uint256 escrowId);

  function createContractEscrow(
    bytes32 listingId,
    address token,
    uint256[] calldata milestoneAmounts,
    uint64 clawbackAfter
  ) external payable returns (uint256 escrowId);

  function deposit(uint256 escrowId, uint256 amount) external payable;
  function setDistributionRoot(uint256 escrowId, bytes32 merkleRoot) external; // Operator/Sponsor
  function claim(uint256 escrowId, uint256 amount, bytes32[] calldata proof) external; // Bounty

  // Contract milestones
  function fundMilestone(uint256 escrowId, uint256 idx, uint256 amount) external payable;
  function approveMilestone(uint256 escrowId, uint256 idx, bytes calldata sponsorSig, bytes calldata operatorSig) external;
  function claimMilestone(uint256 escrowId, uint256 idx) external;

  function refundRemainder(uint256 escrowId) external; // after clawbackAfter
}