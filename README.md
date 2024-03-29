# <img src="logo.svg" alt="Angle Borrowing Module" height="40px"> Angle Borrowing Module - Productive Assets

[![CI](https://github.com/AngleProtocol/borrow-stakedToken/workflows/CI/badge.svg)](https://github.com/AngleProtocol/borrow-stakedToken/actions?query=workflow%3ACI)

## Documentation

This repository contains the contracts of the Angle Protocol Borrowing module adapted to productive assets (e.g. staked tokens that can receive rewards).

### Further Information

For more details about what Angle or the Borrowing module are, you can check Angle documentation [here](https://docs.angle.money) or the contracts for the Borrowing module of the protocol using vanilla collateral assets [here](https://github.com/AngleProtocol/borrow-contracts).

Other Angle-related smart contracts can be found in the following repositories:

- [Angle Core module contracts](https://github.com/AngleProtocol/angle-core)
- [Angle Strategies](https://github.com/AngleProtocol/angle-strategies)
- [Angle Router contracts](https://github.com/AngleProtocol/angle-router)
- [Angle Algorithmic Market Operations](https://github.com/AngleProtocol/angle-amo)

Otherwise, for more info about the protocol, check out [this portal](https://linktr.ee/angleprotocol) of resources.

## Starting

This repo contains the contracts and tests associated to this extension of the Borrowing module. Follow the steps described below if you want to be able to use it by yourself.

It only works with Foundry.

### Install packages

You can install all dependencies by running

```bash
yarn
forge i
```

### Install submodules

Before being able to compile the contracts of the repo, you need to install the repository's submodules.

```bash
git submodule init
git submodule update --remote
```

### Create `.env` file

In order to interact with non local networks, you must create an `.env` that has:

- `PRIVATE_KEY`
- `MNEMONIC`
- network key (eg. `ALCHEMY_NETWORK_KEY`)
- `ETHERSCAN_API_KEY`

For additional keys, you can check the `.env.example` file.

Warning: always keep your confidential information safe.

## Headers

To automatically create headers, follow: <https://github.com/Picodes/headers>

## Foundry Installation

```bash
curl -L https://foundry.paradigm.xyz | bash

source /root/.zshrc
# or, if you're under bash: source /root/.bashrc

foundryup
```

To install the standard library:

```bash
forge install foundry-rs/forge-std
```

To update libraries:

```bash
forge update
```

### Foundry on Docker 🐳

**If you don’t want to install Rust and Foundry on your computer, you can use Docker**
Image is available here [ghcr.io/foundry-rs/foundry](http://ghcr.io/foundry-rs/foundry).

```bash
docker pull ghcr.io/foundry-rs/foundry
docker tag ghcr.io/foundry-rs/foundry:latest foundry:latest
```

To run the container:

```bash
docker run -it --rm -v $(pwd):/app -w /app foundry sh
```

Then you are inside the container and can run Foundry’s commands.

### Tests

You can run tests as follows:

```bash
forge test -vvvv --watch
forge test -vvvv --match-path test/foundry/vaultManager/VaultManagerListing.t.sol
forge test -vvvv --match-test "testAbc*"
```

You can also list tests:

```bash
forge test --list
forge test --list --json --match-test "testXXX*"
```

### Deploying

There is an example script in the `scripts/foundry` folder. Then you can run:

```bash
yarn foundry:deploy <FILE_NAME> --rpc-url <NETWORK_NAME>
```

### Coverage

We recommend the use of this [vscode extension](ryanluker.vscode-coverage-gutters).

```bash
yarn foundry:coverage
```

### Gas report

```bash
yarn foundry:gas
```

## Slither

```bash
pip3 install slither-analyzer
pip3 install solc-select
solc-select install 0.8.11
solc-select use 0.8.11
slither .
```

## Media

Don't hesitate to reach out on [Twitter](https://twitter.com/AngleProtocol) 🐦
