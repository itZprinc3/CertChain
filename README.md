# Blockchain Certificate Generation & Verification System

A decentralized certificate issuance, management, and verification platform built on Ethereum using **Foundry**. Certificate metadata is stored on **IPFS**. Frontend uses plain **HTML + ethers.js**.

Built following the exact project structure and patterns from **Cyfrin Updraft — Foundry Fundamentals** and **Full-Stack Web3 Development** courses.

---

## Project Structure (matches foundry-fund-me-f23)

```
certificate-generation/
├── src/
│   └── CertificateManager.sol          # Main contract (like FundMe.sol)
├── script/
│   ├── DeployCertificateManager.s.sol   # Deploy script (like DeployFundMe.s.sol)
│   ├── HelperConfig.s.sol               # Chain config (like HelperConfig.s.sol)
│   └── Interactions.s.sol               # Interact scripts (like Interactions.s.sol)
├── test/
│   ├── unit/
│   │   └── CertificateManagerTest.t.sol # Unit tests (like FundMeTest.t.sol)
│   └── integration/
│       └── InteractionsTest.t.sol       # Integration tests (like InteractionsTest.t.sol)
├── frontend/
│   └── index.html                       # Full-Stack Web3 frontend
├── foundry.toml
├── Makefile
├── .env.example
└── .gitignore
```

---

## Cyfrin Updraft Concepts Used

### From Foundry Fundamentals

| Concept | Where it's used |
|---|---|
| Custom errors (`ContractName__ErrorName`) | `CertificateManager.sol` — all reverts |
| Variable prefixes (`i_` immutable, `s_` storage) | `CertificateManager.sol` — all state vars |
| CEI pattern (Checks-Effects-Interactions) | `issueCertificate()` function |
| `HelperConfig` for chain-agnostic deploys | `script/HelperConfig.s.sol` |
| `DeployScript` with `vm.startBroadcast` | `script/DeployCertificateManager.s.sol` |
| `Interactions.s.sol` for scripted calls | `script/Interactions.s.sol` |
| `foundry-devops` to find deployed address | `Interactions.s.sol` — `DevOpsTools` |
| Tests use deploy script in `setUp()` | Both test files |
| `makeAddr()` for labeled test addresses | Unit tests |
| `vm.prank()` / `vm.startPrank()` | Unit tests — access control |
| `vm.expectRevert()` with custom errors | Unit tests — revert checks |
| Test modifiers for setup helpers | `issuerAuthorized`, `certificateIssued` |
| Unit vs Integration test split | `test/unit/` and `test/integration/` |
| Makefile with all commands | Root `Makefile` |
| NatSpec documentation | All public functions |

### From Full-Stack Web3 Development

| Concept | Where it's used |
|---|---|
| `ethers.BrowserProvider` (v6) | `frontend/index.html` |
| `eth_requestAccounts` for wallet connect | `connectWallet()` |
| `Contract` for read/write calls | All frontend interactions |
| Event parsing from receipts | `issueCertificate()` — gets cert ID |
| `accountsChanged` / `chainChanged` listeners | Wallet connection handler |
| Chain ID detection for network config | `DOMContentLoaded` init |

---

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [MetaMask](https://metamask.io/) browser extension

### 1. Install Dependencies

```bash
cd "certificate generation"
make install
```

This runs:
- `forge install foundry-rs/forge-std --no-commit`
- `forge install Cyfrin/foundry-devops --no-commit`

### 2. Build & Test

```bash
make build
make test           # all tests
make test-unit      # unit tests only
make test-integration  # integration tests only
make test-gas       # with gas report
```

### 3. Deploy to Anvil (Local)

```bash
# Terminal 1 — start local chain
make anvil

# Terminal 2 — deploy
make deploy
```

Copy the contract address from the output.

### 4. Deploy to Sepolia

```bash
# Set your keys
cp .env.example .env
# Edit .env with SEPOLIA_RPC_URL, PRIVATE_KEY, ETHERSCAN_API_KEY

# Deploy + verify on Etherscan
make deploy-sepolia
```

### 5. Run Frontend

```bash
make serve
# Opens at http://localhost:8080
```

When prompted, paste the deployed contract address.

### 6. Interact via Scripts (like FundFundMe / WithdrawFundMe)

```bash
# Issue a certificate (uses Interactions.s.sol)
make issue

# Authorize a new issuer
make authorize
```

---

## MetaMask Setup for Anvil

1. Add custom network: RPC `http://127.0.0.1:8545`, Chain ID `31337`, Currency `ETH`
2. Import Anvil account #0: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
3. This account is the contract Owner (pre-funded with 10,000 ETH)

---

## IPFS Metadata

Before issuing, upload a JSON file to IPFS via [Pinata](https://www.pinata.cloud/) or [nft.storage](https://nft.storage/):

```json
{
  "name": "Blockchain Fundamentals Certificate",
  "description": "Awarded for completing the course",
  "recipient": "Alice Johnson",
  "course": "Blockchain Fundamentals",
  "issuer": "Academy",
  "date": "2026-05-19",
  "image": "ipfs://QmYourCertificateImageCID"
}
```

Use the resulting CID as the `_ipfsHash` parameter when issuing.

---

## License

MIT
