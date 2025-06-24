# ⚡ AtomicSwapX

> A secure, trustless atomic swap protocol for the Stacks blockchain, written in Clarity.

`AtomicSwapX` is a smart contract that enables atomic swaps between STX and SIP-010 compliant tokens using Hashed Timelock Contracts (HTLCs). It ensures both parties either complete the trade or funds are safely refunded—no trust required.

---

## ✨ Features

- ⛓️ Trustless atomic swaps via SHA-256 hashlocks
- 🕓 Time-bound refunds using block height
- 🧾 Swap state tracking and auditability
- 🔒 Secure token locking and redemption
- 🔄 Compatible with STX and SIP-010 token standards
- 🧩 Minimal and composable — ideal for DEXs or escrow systems

---

## 📦 Contract Overview

| Function        | Type       | Description                                      |
|-----------------|------------|--------------------------------------------------|
| `create-swap`   | Public     | Initiate a swap with recipient, hashlock, and expiry |
| `redeem-swap`   | Public     | Redeem locked tokens using the correct preimage |
| `refund-swap`   | Public     | Reclaim tokens after expiry if not redeemed     |
| `get-swap`      | Read-Only  | View swap data by ID                            |
| `is-active`     | Read-Only  | Check if a swap is currently active             |

---

## 🛠️ Usage

### 📄 1. Creating a Swap

```clarity
(create-swap
  recipient
  token-contract
  token-amount
  hashlock
  expiration-block
)
recipient: Principal who can redeem the swap

token-contract: SIP-010 token or 'SP...::stx

token-amount: Amount to lock

hashlock: SHA-256 hash of the secret

expiration-block: Block height at which funds can be refunded

🔓 2. Redeeming a Swap
clarity
Copy
Edit
(redeem-swap
  swap-id
  preimage
)
Reveals the secret used to unlock the funds.

Funds are transferred to the recipient.

🔁 3. Refunding a Swap
c
Copy
Edit
(refund-swap
  swap-id
)
Only possible after expiration-block.

Refunds tokens to the original sender.

🧪 Testing
Write your tests using Clarinet:

bash
Copy
Edit
clarinet test
Common test scenarios:

Valid create/redeem flow

Invalid preimage attempts

Expiry refund behavior

Re-entrancy and double spend protection

📐 Data Structures
swap
c
Copy
Edit
{
  sender: principal,
  recipient: principal,
  token: principal,
  amount: uint,
  hashlock: (buff 32),
  expiry: uint,
  redeemed: bool
}
Swap entries stored in a map by a unique swap ID.

Status is updated after redemption or refund.

🔒 Security Notes
Funds are locked, not transferred, until swap is completed.

Redeem fails if preimage doesn’t match hashlock.

Refund fails if not expired or already redeemed.

💼 Integration
Can be integrated into:

Decentralized exchanges (DEXs)

Multi-asset wallets

Cross-chain swap relayers

Token escrow or NFT marketplaces

