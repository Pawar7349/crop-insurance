# Crop Insurance Protocol

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue)](https://soliditylang.org)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FF6B6B)](https://foundry.sh)
[![Tests](https://img.shields.io/badge/Tests-15%20passing-brightgreen)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> Decentralized crop insurance built on Ethereum. Farmers pay a small premium and get protected against crop failure — no middlemen, no paperwork, no unfair claim rejections.

---

## Live Deployment

| Network | Address | Etherscan |
|---------|---------|-----------|
| Sepolia | `0x8EcDD232984746f60B1E54C3462D51fCf795Cd0b` | [View Verified Contract](https://sepolia.etherscan.io/address/0x8EcDD232984746f60B1E54C3462D51fCf795Cd0b) |

---

## Why I Built This

Farmers globally lose billions every year to crop failure. But the bigger problem isn't the crop failure — it's the insurance system. Claims take months. Paperwork gets lost. Companies find loopholes to deny payouts.

I wanted to build something where the rules are written in code, visible to everyone, and executed automatically. No insurance agent deciding your fate. If your policy says you get paid, you get paid.

---

## How It Works

1. **Register** — Farmer calls `registerPolicy()` with ETH premium based on crop type and land area
2. **Activate** — Owner verifies and activates the policy
3. **Claim** — If crop fails, owner processes the claim and farmer receives 10x their premium instantly
4. **Refund** — If the owner never activates within 7 days, farmer can pull their full premium back — no questions asked
5. **Auto-expire** — After 180 days with no claim, Chainlink Automation expires the policy and returns 50% of the premium

The farmer is never at the mercy of anyone. Either their claim gets processed, or they get their money back.

---

## Premium Rates

Premiums are priced in ETH using a live Chainlink ETH/USD price feed  so the cost always reflects real dollar value regardless of ETH price movements.

| Crop | Rate per Acre | Coverage |
|------|--------------|----------|
| Wheat | $2 USD | 10x premium |
| Rice | $4 USD | 10x premium |
| Cotton | $6 USD | 10x premium |

---

## Tech Stack

- **Solidity** ^0.8.24
- **Foundry** — testing and deployment
- **Chainlink Price Feeds** — live ETH/USD pricing for fair premiums
- **Chainlink Automation** — trustless auto-expiry after 180 days

---

## Quick Start

```bash
git clone https://github.com/Pawar7349/crop-insurance.git
cd crop-insurance
forge install
forge test
```

---

## Contract Functions

| Function | Access | Description |
|----------|--------|-------------|
| `registerPolicy()` | Farmer | Create policy, pay premium |
| `activatePolicy()` | Owner | Activate coverage after verification |
| `processClaim()` | Owner | Pay 10x coverage to farmer |
| `claimPendingRefund()` | Farmer | Full refund if not activated within 7 days |
| `expirePolicy()` | Anyone | Triggers 50% refund after 180 days |
| `withdrawProfit()` | Owner | Withdraw funds above total active coverage |
| `checkUpkeep()` | Chainlink | Checks for policies ready to expire |
| `performUpkeep()` | Chainlink | Automatically expires overdue policies |

---

## Policy Lifecycle

```
INACTIVE ──► (activated by owner)  ──► ACTIVE ──► (claim filed)  ──► CLAIMED
                                               └──► (180 days)   ──► EXPIRED
         └──► (7 days, not activated)          ──────────────────►  EXPIRED
```

---

## Gas Costs (Sepolia)

| Function | Estimated Gas |
|----------|--------------|
| `registerPolicy` | ~150,000 |
| `activatePolicy` | ~45,000 |
| `processClaim` | ~65,000 |
| `claimPendingRefund` | ~55,000 |

---

## Security

- **Checks-Effects-Interactions** pattern on all functions that transfer ETH — state is always updated before any external call
- **Owner-only access control** via `onlyOwner` modifier on sensitive functions
- **Chainlink oracle** for tamper-proof ETH/USD pricing
- **No reentrancy risk** — effects happen before interactions throughout

---

## Project Structure

```
src/
  CropInsurance.sol        # Main contract
test/
  CropInsurance.t.sol      # 17 tests covering happy paths and edge cases
```

---

## Author

Built by [Pawar7349](https://github.com/Pawar7349)

---

## License

MIT