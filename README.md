# Lucky ARB Contract

- [Overview](#overview)
- [Features](#features)
- [How It Works](#how-it-works)
- [Getting Started](#getting-started)
  - [Requirements](#requirements)
  - [Quickstart](#quickstart)
- [Usage](#usage)
  - [Start a local node](#start-a-local-node)
  - [Deploy](#deploy)
  - [Testing](#testing)
    - [Test Coverage](#test-coverage)

## Overview

**Lucky ARB** is an ERC20 token with a built-in decentralized lottery mechanism, providing an exciting and fair way to distribute the token supply. Players participate by depositing ARB tokens and selecting a lucky number. The more tokens a player deposits, the higher their chances of winning. After the lottery closes, a random lucky number is generated through an oracle. If a player's chosen number falls within a specific range around the winning number, they win the lottery. Winners can then claim rewards that were predetermined before the lottery started. This innovative approach ensures that the entire token supply is distributed as rewards, making participation both engaging and rewarding.

## Features

Lucky ARB operates a lottery system with the following features:

- **ERC20 Token Integration**: Lucky ARB is an ERC20 token, and all transactions and balances follow the ERC20 standard.
- **Reward Distribution**: The entire supply of Lucky ARB tokens is distributed as rewards to players participating in the lottery.
- **Increased Winning Chances**: Players can increase their chances of winning by depositing more ARB tokens.
- **Decentralized & Transparent**: Built on the Arbitrum blockchain, ensuring fairness and transparency.

## How It Works

1. **Deposit ARB Tokens**  
  Players participate in the lottery by depositing ARB tokens (`deposited_arb`). The minimum required deposit is 1 ARB token.

2. **Pick a Lucky Number**  
  After depositing, players choose a unique number (`picked_number`), which they believe will be the winning number. This number is used to determine the winning range based on the player’s deposit amount.

3. **Lucky Number Request**  
  Once the lottery closes, the contract owner requests a lucky number from an oracle. This ensures a fair and transparent selection process.

4. **Winning Criteria**  
  If the generated lucky number falls within the interval `<picked_number - deposited_arb, picked_number + deposited_arb>`, the player wins the lottery.

5. **Claiming Rewards**  
  Winners can claim their rewards. The reward amount is fixed and set at the beginning of the lottery round.

## Getting Started

### Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [foundry](https://book.getfoundry.sh/getting-started/installation)

### Quickstart

```bash
git clone https://github.com/fsosa98/lucky-arb
cd lucky-arb
forge build
```

## Usage

### Start a local node

```
make anvil
```

### Deploy

This will default to your local node. You need to have it running in another terminal in order for it to deploy.

```
make deploy
```

### Testing

To run the tests:

```bash
forge test
```

#### Test Coverage

```
forge coverage
```
