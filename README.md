# 🏦 StableCoin Rewards Vault

[![Solidity](https://img.shields.io/badge/Solidity-0.8.28-blue)](https://soliditylang.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.0-blue)](https://openzeppelin.com/)

# StableCoin Rewards Vault

An epoch-based staking vault that modifies the MasterChef/Synthetix reward distribution algorithm to operate on epoch cycles rather than per-block distribution.

## Overview

This implementation diverges from traditional MasterChef contracts by introducing epoch-based reward distribution. While MasterChef distributes rewards every block based on continuous time-weighted stakes, this system accumulates rewards during lock periods and distributes them based on epoch participation.

### Key Innovation: Epoch-Based Distribution

Traditional MasterChef:
- Distributes rewards every block
- Continuous reward accrual
- Immediate liquidity

This Implementation:
- Distributes rewards per epoch cycle
- Rewards only accrue during lock periods
- Structured liquidity windows

## Architecture

```
┌─────────────────────────┐
│ StableCoinRewardsVault  │ ← Epoch-based reward distribution
├─────────────────────────┤
│   EpochStakingVault     │ ← Epoch lifecycle management
├─────────────────────────┤
│       ERC4626           │ ← Tokenized vault standard
│    AccessControl        │ ← Role-based permissions
│   ReentrancyGuard       │ ← Security layer
└─────────────────────────┘
```

## Epoch Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              EPOCH N TIMELINE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│     DEPOSIT WINDOW (7 days)     │         LOCK PERIOD (90 days)             │
├─────────────────────────────────┼──────────────────────────────────────────┤
│ • Deposits/Withdrawals: OPEN    │ • Deposits/Withdrawals: CLOSED           │
│ • Reward Addition: BLOCKED      │ • Reward Addition: ALLOWED               │
│ • Parameters: Updatable (24h)   │ • Parameters: LOCKED                     │
│ • Rewards: NOT CLAIMABLE        │ • Rewards: CLAIMABLE                     │
└─────────────────────────────────┴──────────────────────────────────────────┘
                                  ↓
                          Automatic transition to Epoch N+1
```

## Modified Distribution Algorithm

The core innovation is the dual accumulator system that enables epoch-based distribution:

```solidity
// Two accumulators instead of one
uint256 public totalRewardsPerShareAccumulator;      // Tracks all rewards added
uint256 public claimableRewardsPerShareAccumulator;  // Tracks claimable rewards

// Synchronization function - the key difference from MasterChef
function syncToCurrentEpoch() internal {
    if (
        (block.timestamp < startTime + DEPOSIT_WINDOW ||
         block.timestamp > startTime + DEPOSIT_WINDOW + LOCK_PERIOD) &&
        totalRewardsPerShareAccumulator != claimableRewardsPerShareAccumulator
    ) {
        // Makes accumulated rewards claimable outside deposit window
        claimableRewardsPerShareAccumulator = totalRewardsPerShareAccumulator;
    }
}
```

### How It Differs From MasterChef

**MasterChef Pattern:**
```solidity
// Rewards distributed per block
rewardPerBlock = totalRewards / numberOfBlocks
pendingReward = (block.number - lastRewardBlock) * rewardPerBlock * userShare / totalShares
```

**This Implementation:**
```solidity
// Rewards added during lock period, distributed based on epoch participation
rewardPerShare += (addedRewards * 1e27) / totalSupply
userRewards = shares * (claimableRewardsPerShare - userDebtPerShare) / 1e27
```

## State Flow Visualization

```
Block Timeline:
├─ Block N: User deposits during window
│   └─ userDebt = currentAccumulator (prevents claiming existing rewards)
│
├─ Block N+100: Deposit window closes
│   └─ No state change yet
│
├─ Block N+101: Manager adds rewards
│   └─ totalRewardsPerShareAccumulator increases
│   └─ claimableRewardsPerShareAccumulator unchanged (rewards locked)
│
├─ Block N+200: User interacts (outside deposit window)
│   └─ syncToCurrentEpoch() called
│   └─ claimableRewardsPerShareAccumulator = totalRewardsPerShareAccumulator
│   └─ User can now claim rewards
```

## Technical Implementation Details

### 1. Reward Calculation Precision

Uses 1e27 scaling factor to prevent precision loss:
```solidity
uint256 rewardPerShare = amount.mulDiv(1e27, totalSupply, Math.Rounding.Floor);
if (rewardPerShare == 0) revert RewardAmountTooLowComparedToTotalSupply();
```

### 2. Auto-Claim Mechanism

The `updateReward` modifier automatically processes rewards on user interactions:
```solidity
modifier updateReward(address user) {
    syncToCurrentEpoch();  // Critical: Check if we should unlock rewards
    UserInfo storage _user = userInfo[user];
    uint256 rewards = claimableRewards(user);
    _user.rewardsPerShareDebt = claimableRewardsPerShareAccumulator;
    
    if (rewards > 0) {
        _user.totalRewardsClaimed += rewards;
        REWARD_TOKEN.safeTransfer(user, rewards);
        emit RewardsClaimed(user, rewards);
    }
    _;
}
```

### 3. Epoch Transition Safety

Prevents operations during wrong epoch phases:
```solidity
modifier isOpen() { 
    if (block.timestamp >= startTime + DEPOSIT_WINDOW && 
        block.timestamp < startTime + DEPOSIT_WINDOW + LOCK_PERIOD) {
        revert EpochLocked();
    }
    _;
}

modifier isLocked() { 
    if (block.timestamp < startTime + DEPOSIT_WINDOW || 
        block.timestamp >= startTime + DEPOSIT_WINDOW + LOCK_PERIOD) {
        revert NotLocked();
    }
    _;
}
```

## Security Considerations

### Time-Based Attack Vectors
- **Addressed**: Parameter updates restricted to first 24h
- **Addressed**: Deposits/withdrawals blocked during reward distribution
- **Addressed**: Epoch transitions require explicit manager action

### Economic Security
- **Min/Max Limits**: Prevent dust attacks and whale domination
- **Pool Size Cap**: Limits total exposure
- **Reward Validation**: Ensures meaningful reward distribution

## Deployment Example

```solidity
// Deploy with epoch-specific parameters
const vault = await StableCoinRewardsVault.deploy(
    "0x...",           // USDC or other stable asset
    "Epoch USDC",      // Clear naming convention
    "epUSDC",          // Indicates epoch-based
    admin,             // Multisig recommended
    manager,           // Can be automated keeper
    100e6,             // $100 minimum (USDC decimals)
    10000e6,           // $10k maximum
    1000000e6          // $1M pool cap
);

// Start first epoch
await vault.connect(manager).startEpoch();
```

## Testing Considerations

Critical test scenarios for epoch-based distribution:
- Epoch boundary conditions
- Reward accumulation across multiple epochs
- User joining mid-epoch
- Multiple reward additions in single epoch
- Gas optimization verification

## Future Improvements

- **Dynamic Epochs**: Variable duration based on TVL
- **Multi-Asset Rewards**: Distribute multiple tokens
- **Boost Mechanism**: NFT or veToken multipliers
- **Cross-Epoch Strategies**: Compound rewards automatically

---

*Note: This implementation significantly modifies the standard MasterChef algorithm. Ensure thorough understanding of epoch mechanics before deployment.*