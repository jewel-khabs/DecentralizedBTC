# DecentralizedBTC

DecentralizedBTC is a cross-chain AMM liquidity pool for decentralized Bitcoin custody built on the Stacks blockchain using Clarity smart contracts. It provides automated market making, yield farming, and decentralized custody features for Bitcoin-based assets.

## Features

### Core AMM Functionality
- **Liquidity Pools**: Create and manage token pairs with automated market making
- **Token Swaps**: Execute token swaps with configurable fees (0.3% default)
- **Liquidity Provision**: Add and remove liquidity with proportional rewards
- **Slippage Protection**: Built-in slippage tolerance for all trading operations

### Cross-Chain Bitcoin Custody
- **BTC Address Locking**: Lock STX tokens against Bitcoin addresses
- **Decentralized Custody**: Secure cross-chain asset management
- **Custody Tracking**: Monitor and manage locked positions

### Yield Farming
- **Reward Staking**: Stake liquidity positions for additional rewards
- **Reward Distribution**: Automated reward calculation and distribution
- **Compound Interest**: Reinvest rewards for compound growth

### Security Features
- **Pause Mechanism**: Emergency pause functionality for admin control
- **Ownership Controls**: Restricted admin functions with proper access control
- **Input Validation**: Comprehensive parameter validation and error handling

## Technical Specifications

### Blockchain
- **Network**: Stacks
- **Language**: Clarity 2.0
- **Epoch**: 2.5

### Token Details
- **Name**: DecentralizedBTC
- **Symbol**: DBTC
- **Decimals**: 8
- **Total Supply**: 21,000,000 DBTC (with 8 decimals)
- **Standard**: SIP-010 compatible functions

### AMM Configuration
- **Swap Fee**: 0.3% (30 basis points)
- **Protocol Fee**: 0.1% (10 basis points)
- **Minimum Liquidity**: 1,000 units
- **Fee Denominator**: 10,000 (for percentage calculations)

## Installation

### Prerequisites
- Node.js (v16 or higher)
- Clarinet CLI
- Git

### Setup
```bash
# Clone the repository
git clone <repository-url>
cd DecentralizedBTC

# Navigate to contract directory
cd DecentralizedBTC_contract

# Install dependencies
npm install

# Run tests
npm test

# Run tests with coverage
npm run test:report

# Watch mode for development
npm run test:watch
```

### Project Structure
```
DecentralizedBTC_contract/
├── contracts/
│   └── DecentralizedBTC.clar    # Main smart contract
├── tests/                       # Test files
├── settings/                    # Clarinet settings
├── .vscode/                     # VS Code configuration
├── Clarinet.toml               # Clarinet project configuration
├── package.json                # Node.js dependencies
├── tsconfig.json               # TypeScript configuration
└── vitest.config.js            # Test configuration
```

## Usage Examples

### Creating a Liquidity Pool
```clarity
;; Create a new liquidity pool
(contract-call? .DecentralizedBTC create-pool
  'SP000000000000000000002Q6VF78.token-a  ;; Token A principal
  'SP000000000000000000002Q6VF78.token-b  ;; Token B principal
  u1000000                                  ;; Initial amount A
  u2000000)                                 ;; Initial amount B
```

### Adding Liquidity
```clarity
;; Add liquidity to an existing pool
(contract-call? .DecentralizedBTC add-liquidity
  u1          ;; Pool ID
  u500000     ;; Amount A to add
  u1000000    ;; Amount B to add
  u100000)    ;; Minimum shares expected
```

### Token Swapping
```clarity
;; Swap tokens in a pool
(contract-call? .DecentralizedBTC swap-exact-tokens-for-tokens
  u1                                        ;; Pool ID
  u100000                                   ;; Amount in
  u95000                                    ;; Minimum amount out
  'SP000000000000000000002Q6VF78.token-a)  ;; Input token
```

### Cross-Chain Custody
```clarity
;; Lock STX for BTC custody
(contract-call? .DecentralizedBTC lock-btc-custody
  "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"  ;; BTC address
  u5000000)                                        ;; STX amount to lock

;; Unlock custody
(contract-call? .DecentralizedBTC unlock-btc-custody)
```

## Contract Functions Documentation

### Public Functions

#### Token Management
- `transfer(amount, sender, recipient, memo)` - Transfer tokens between accounts
- `get-balance(account)` - Get token balance for an account
- `get-total-supply()` - Get total token supply

#### Pool Management
- `create-pool(token-a, token-b, initial-a, initial-b)` - Create new liquidity pool
- `add-liquidity(pool-id, amount-a, amount-b, min-shares)` - Add liquidity to pool
- `remove-liquidity(pool-id, shares, min-amount-a, min-amount-b)` - Remove liquidity from pool

#### Trading
- `swap-exact-tokens-for-tokens(pool-id, amount-in, min-amount-out, token-in)` - Execute token swap

#### Cross-Chain Custody
- `lock-btc-custody(btc-address, stx-amount)` - Lock STX for BTC custody
- `unlock-btc-custody()` - Unlock previously locked custody

#### Yield Farming
- `stake-for-rewards(pool-id, amount)` - Stake for yield farming rewards

#### Admin Functions
- `set-contract-uri(uri)` - Set contract metadata URI
- `toggle-pause()` - Emergency pause/unpause contract

### Read-Only Functions
- `get-pool(pool-id)` - Get pool information
- `get-user-liquidity(user, pool-id)` - Get user's liquidity position
- `get-pool-by-tokens(token-a, token-b)` - Find pool by token pair
- `get-custody-record(user)` - Get user's custody record
- `calculate-swap-output(reserve-in, reserve-out, amount-in, fee-rate)` - Calculate swap output

## Deployment Guide

### Local Development
```bash
# Start Clarinet console
clarinet console

# Deploy contract
::deploy_contracts

# Interact with contract
(contract-call? .DecentralizedBTC get-name)
```

### Testnet Deployment
```bash
# Deploy to testnet
clarinet deploy --testnet

# Verify deployment
clarinet call --testnet .DecentralizedBTC get-name
```

### Mainnet Deployment
```bash
# Deploy to mainnet (ensure proper testing first)
clarinet deploy --mainnet
```

## Security Considerations

### Access Controls
- Contract owner has exclusive access to admin functions
- Emergency pause mechanism for critical situations
- Input validation for all public functions

### Economic Security
- Slippage protection prevents front-running attacks
- Minimum liquidity requirements prevent dust attacks
- Fee structure incentivizes proper market making

### Cross-Chain Risks
- BTC custody relies on external verification
- STX locking provides economic security for custody
- Users should verify BTC address ownership

### Best Practices
- Always use minimum output amounts for swaps
- Verify pool parameters before adding liquidity
- Monitor custody records for unauthorized changes
- Keep private keys secure for all operations

### Audit Recommendations
- Conduct formal verification of mathematical operations
- Test edge cases with extreme values
- Verify cross-chain custody mechanisms
- Review access control implementations

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | ERR_OWNER_ONLY | Operation restricted to contract owner |
| 101 | ERR_INSUFFICIENT_BALANCE | Insufficient token balance |
| 102 | ERR_INVALID_AMOUNT | Invalid amount parameter |
| 103 | ERR_POOL_NOT_EXISTS | Specified pool does not exist |
| 104 | ERR_INSUFFICIENT_LIQUIDITY | Insufficient liquidity for operation |
| 105 | ERR_SLIPPAGE_TOO_HIGH | Slippage exceeds tolerance |
| 106 | ERR_ZERO_AMOUNT | Amount cannot be zero |
| 107 | ERR_INVALID_TOKEN | Invalid token address |
| 108 | ERR_POOL_EXISTS | Pool already exists for token pair |

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`npm test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

This project is licensed under the ISC License - see the package.json file for details.

## Support

For support and questions:
- Create an issue in the repository
- Review the test files for usage examples
- Check the Clarity documentation for language specifics

## Disclaimer

This is experimental software. Use at your own risk. Always conduct thorough testing and audits before deploying to mainnet or handling significant value.