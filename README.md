# Revenue Sharing Protocol — Stacks Smart Contract

A transparent, on-chain revenue distribution protocol built on Stacks. Stakeholders contribute revenue to a shared pool and receive proportional units; units are redeemed for a pro-rata share of the live pool balance. A platform retention fee supports the protocol manager.

## Overview

The Revenue Sharing contract enables fair, auditable distribution of revenue among multiple stakeholders. Every contribution mints units proportional to the current pool. When stakeholders claim their share, they receive the live pool value of their units — meaning pool growth benefits all unit holders.

## Features

- **Revenue Contributions**: Any principal can contribute to the sharing pool
- **Proportional Units**: Contributions mint units proportional to pool state at contribution time
- **Pro-Rata Claims**: Units are redeemed for their share of the live pool balance
- **Retention Fee**: 4 bps platform fee on `pay-into-pool` transactions
- **Distribution Halt**: Manager can pause all contributions and claims
- **Retention Extraction**: Manager extracts accumulated retention fees
- **Emergency Recovery**: Safety drain for the revenue manager

## Contract Architecture

### Data Structures

| Map | Key | Value | Purpose |
|-----|-----|-------|---------|
| `stakeholder-contributions` | `principal` | `uint` | Recorded contributions per stakeholder |
| `stakeholder-units` | `principal` | `uint` | Unit balance per stakeholder |

### Key Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `RETENTION-RATE` | `4` | 4 basis points platform retention |
| `UNIT-BASE` | `10000` | Divisor for fee calculation |

## Function Reference

### Public Functions

#### `contribute-revenue (amount uint)`
Contributes `amount` microSTX to the revenue pool. Mints proportional units to the caller.

#### `claim-revenue-share (units uint)`
Redeems `units` for their proportional share of the live pool balance. Burns units and transfers payout.

#### `pay-into-pool (amount uint)`
Deposits `amount` plus the 4 bps retention fee into the pool.

#### `set-distribution-halted (halted bool)`
Manager-only. Pauses or resumes all pool operations.

#### `extract-retention (amount uint)`
Manager-only. Withdraws up to `amount` of accumulated retention from the pool.

#### `recover-pool-funds (amount uint)`
Manager-only. Emergency recovery of pool funds.

### Read-Only Functions

| Function | Returns |
|----------|---------|
| `get-stakeholder-contribution (principal)` | Recorded contribution |
| `get-stakeholder-units (principal)` | Current unit balance |
| `get-revenue-pool` | Revenue pool variable |
| `get-total-distributed` | All-time distributed amount |
| `calculate-retention (uint)` | Retention fee for a given amount |
| `get-pool-balance` | Live STX balance of contract |
| `is-distribution-halted` | Whether distributions are active |

## Error Codes

| Code | Constant | Meaning |
|------|----------|---------|
| `u700` | `ERR-MANAGER-ONLY` | Caller is not the revenue manager |
| `u701` | `ERR-REVENUE-DEPLETED` | Pool is empty |
| `u702` | `ERR-DISTRIBUTION-PENDING` | Prior distribution not finalized |
| `u703` | `ERR-NULL-CONTRIBUTION` | Zero-value contribution |
| `u704` | `ERR-ALLOCATION-REJECTED` | Unit allocation rejected |
| `u705` | `ERR-PERIOD-CLOSED` | Distribution period is closed |
| `u706` | `ERR-STAKE-INSUFFICIENT` | Insufficient units to claim |
| `u707` | `ERR-DISTRIBUTION-HALTED` | Distributions currently halted |
| `u708` | `ERR-UNIT-CALC-ERROR` | Division by zero in unit calc |
| `u709` | `ERR-PAYOUT-DEFICIT` | Extraction exceeds pool balance |
| `u710` | `ERR-TRANSFER-ERROR` | Transfer transaction failed |

## Revenue Model

- Stakeholders who contribute earlier receive units at a lower pool-to-balance ratio, giving them a larger slice
- Late contributors receive fewer units per STX as the pool grows, reflecting dilution
- `total-distributed` tracks all-time payouts for off-chain reporting and auditing
- Retention fee (4 bps) only applies to `pay-into-pool`, not direct contributions

## Deployment
```bash
clarinet deploy --network testnet
```
