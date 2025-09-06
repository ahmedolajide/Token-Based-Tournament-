# Token-Based Tournament Smart Contract

A robust Clarity smart contract for managing competitive tournaments with STX token entry fees, automated prize distribution, and comprehensive tournament lifecycle management.

## 🎯 Overview

This contract enables anyone to create and manage token-based tournaments on the Stacks blockchain. Participants pay entry fees in STX tokens, which form the prize pool for the winner, minus a configurable platform fee.

## ✨ Key Features

### Tournament Management
- **Create Tournaments**: Set entry fees, participant limits (max 100), and duration
- **State Management**: Open → Active → Ended/Cancelled workflow
- **Flexible Configuration**: Customizable parameters for each tournament

### Participant System
- **Registration**: Pay entry fees to join tournaments
- **Validation**: Comprehensive checks for eligibility and balance
- **Tracking**: Monitor participant status and tournament progress

### Prize Distribution
- **Automated Rewards**: Winners claim prize pools automatically
- **Platform Fees**: Configurable fee structure (default 2.5%)
- **Refund System**: Full refunds for cancelled tournaments

### Security & Safety
- **Access Control**: Owner-only functions for sensitive operations
- **State Validation**: Proper tournament phase management
- **Double-spend Protection**: Prevents duplicate claims and registrations
- **Balance Verification**: Ensures sufficient funds before transactions

## 📋 Contract Functions

### Public Functions

| Function | Description | Access |
|----------|-------------|--------|
| `create-tournament` | Create new tournament with fee, max participants, duration | Anyone |
| `register-tournament` | Join tournament by paying entry fee | Anyone |
| `start-tournament` | Begin tournament competition | Owner Only |
| `declare-winner` | End tournament and set winner | Owner Only |
| `claim-reward` | Winner claims prize pool | Winner Only |
| `cancel-tournament` | Cancel tournament before start | Owner Only |
| `claim-refund` | Get refund for cancelled tournaments | Participants |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-tournament` | Retrieve tournament details |
| `get-participant-status` | Check participant registration status |
| `get-tournament-participants` | List all tournament participants |
| `get-platform-fee-rate` | Current platform fee percentage |
| `get-current-tournament-id` | Latest tournament ID |

## 🚀 Usage Examples

### Creating a Tournament
```clarity
;; Create tournament: 1000 STX entry fee, max 10 participants, 1000 blocks duration
(contract-call? .tournament create-tournament u1000000000 u10 u1000)
```

### Joining a Tournament
```clarity
;; Register for tournament ID 1
(contract-call? .tournament register-tournament u1)
```

### Starting & Managing Tournament
```clarity
;; Start tournament (owner only)
(contract-call? .tournament start-tournament u1)

;; Declare winner (owner only)
(contract-call? .tournament declare-winner u1 'SP1234...WINNER)
```

### Claiming Rewards
```clarity
;; Winner claims prize pool
(contract-call? .tournament claim-reward u1)
```

## 💰 Fee Structure

- **Platform Fee**: 2.5% of prize pool (adjustable by contract owner)
- **Winner Reward**: Prize pool minus platform fee
- **Refunds**: 100% entry fee for cancelled tournaments

## 🔒 Tournament States

1. **Open (1)**: Registration phase, participants can join
2. **Active (2)**: Tournament in progress, no new registrations
3. **Ended (3)**: Winner declared, rewards claimable
4. **Cancelled (4)**: Tournament cancelled, refunds available

## ⚠️ Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 100 | ERR_NOT_OWNER | Only tournament owner can perform this action |
| 101 | ERR_NOT_PARTICIPANT | User not registered for tournament |
| 102 | ERR_TOURNAMENT_NOT_OPEN | Tournament not accepting registrations |
| 103 | ERR_TOURNAMENT_NOT_ACTIVE | Tournament not in active state |
| 104 | ERR_TOURNAMENT_NOT_ENDED | Tournament hasn't ended yet |
| 105 | ERR_INSUFFICIENT_BALANCE | Not enough STX for entry fee |
| 106 | ERR_ALREADY_REGISTERED | Already registered for tournament |
| 107 | ERR_INVALID_WINNER | Winner not a valid participant |
| 108 | ERR_ALREADY_CLAIMED | Reward/refund already claimed |
| 109 | ERR_INVALID_TOURNAMENT | Invalid tournament parameters |
| 110 | ERR_TOURNAMENT_FULL | Tournament has reached max participants |

## 🛡️ Security Features

- **Owner Verification**: Critical functions restricted to tournament owners
- **Balance Checks**: Validates sufficient STX before transfers
- **State Guards**: Ensures operations only in appropriate tournament phases
- **Claim Protection**: Prevents double-spending of rewards/refunds
- **Participant Limits**: Maximum 100 participants per tournament

## 📊 Contract Specifications

- **Language**: Clarity
- **Blockchain**: Stacks
- **Token**: STX
- **Max Participants**: 100 per tournament
- **Max Platform Fee**: 10%
- **Contract Size**: 299 lines
