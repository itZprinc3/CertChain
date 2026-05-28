# Blockchain Certificate Generation & Verification System

A decentralized certificate issuance, management, and verification platform built on Ethereum using **Foundry**. Certificate metadata is stored on **IPFS**. Frontend uses plain **HTML + ethers.js**.

Built following the exact project structure and patterns from **Cyfrin Updraft — Foundry Fundamentals** and **Full-Stack Web3 Development** courses.

---

## Project Structure 

```
certificate-generation/
├── src/
│   └── CertificateManager.sol          
├── script/
│   ├── DeployCertificateManager.s.sol   
│   ├── HelperConfig.s.sol               
│   └── Interactions.s.sol               
├── test/
│   ├── unit/
│   │   └── CertificateManagerTest.t.sol 
│   └── integration/
│       └── InteractionsTest.t.sol       
├── frontend/
│   └── index.html                       
├── foundry.toml
├── Makefile
├── .env.example
└── .gitignore
```


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
