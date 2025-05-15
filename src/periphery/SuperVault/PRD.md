# SuperVault PPS Calculator Microservice - PRD

## Overview
This document outlines the requirements for creating a Python microservice that calculates the price per share (PPS) for any SuperVault on the Superform platform. The service will expose RESTful APIs via FastAPI to provide PPS calculations and related metadata.

## Background
SuperVault is a vault aggregator that combines multiple yield-bearing stablecoins. Calculating the accurate price per share (PPS) is essential for determining the value of a user's holdings. The calculation involves retrieving data from multiple yield sources and their corresponding oracles to determine the total value locked (TVL) in the vault.

## Objectives
- Create a public, open-source repository with a Python microservice for PPS calculation
- Implement FastAPI endpoints to provide real-time PPS data
- Support monitoring and historical data tracking for SuperVaults
- Ensure scalability and reliability for production use

## Technical Requirements

### Core Functionality
1. **PPS Calculation Logic**
   - Retrieve the list of yield sources using `getYieldSourcesList`
   - For each yield source, call `getYieldSource` to get source details
   - For each source, call `getTVLByOwnerOfShares` to get TVL
   - Aggregate all TVLs to calculate the total assets 
   - Divide total assets by total supply to determine PPS

2. **API Endpoints**
   - `GET /health` - Service health check
   - `GET /api/v1/supervaults` - List all supervised SuperVaults
   - `GET /api/v1/supervault/{address}/pps` - Get current PPS for a specific SuperVault
   - `GET /api/v1/supervault/{address}/details` - Get detailed information about a SuperVault
   - `GET /api/v1/supervault/{address}/tvl` - Get TVL breakdown by yield source
   - `GET /api/v1/supervault/{address}/history` - Get historical PPS data (optional)

3. **Implementation Details**
   - Use web3.py for blockchain interactions
   - Implement caching to reduce RPC calls
   - Support multiple blockchain networks (configurable)
   - Include rate limiting and error handling

### Repository Structure
```
supervault-pps-calculator/
├── README.md                      # Project documentation
├── .gitignore                     # Git ignore file
├── docker-compose.yml             # Docker configuration
├── Dockerfile                     # Docker build instructions
├── requirements.txt               # Python dependencies
├── config/
│   ├── __init__.py
│   ├── settings.py                # Configuration settings
│   └── contracts.py               # Contract addresses and ABIs
├── app/
│   ├── __init__.py
│   ├── main.py                    # FastAPI entry point
│   ├── models/                    # Response/Request Pydantic models
│   │   ├── __init__.py
│   │   └── schemas.py
│   ├── api/                       # API routes
│   │   ├── __init__.py
│   │   ├── v1/
│   │   │   ├── __init__.py
│   │   │   └── routes.py
│   ├── services/                  # Business logic
│   │   ├── __init__.py
│   │   ├── pps_calculator.py      # Core calculation logic
│   │   └── blockchain.py          # Web3 interaction logic
│   └── utils/                     # Utility functions
│       ├── __init__.py
│       ├── cache.py               # Caching utils
│       └── helpers.py             # Helper functions
└── tests/                         # Unit and integration tests
    ├── __init__.py
    ├── conftest.py
    └── test_pps_calculator.py
```

## Files to Copy from Original Repository
1. Contract ABIs:
   - SuperVault.json
   - SuperVaultStrategy.json
   - SuperVaultAggregator.json
   - YieldSourceOracle.json (if available)

2. Relevant interfaces:
   - ISuperVaultStrategy.sol (for reference)
   - ISuperVault.sol (for reference)

## API Response Examples

### GET /api/v1/supervault/{address}/pps
```json
{
  "address": "0x123...",
  "pps": "1.023456789012345678",
  "timestamp": 1674567890,
  "total_assets": "10000000000000000000000",
  "total_shares": "9770000000000000000000",
  "asset": {
    "address": "0xabc...",
    "symbol": "USD",
    "decimals": 18
  }
}
```

### GET /api/v1/supervault/{address}/tvl
```json
{
  "address": "0x123...",
  "total_tvl": "10000000000000000000000",
  "yield_sources": [
    {
      "address": "0xdef...",
      "oracle": "0xfed...",
      "name": "Aave USD",
      "tvl": "3000000000000000000000",
      "percentage": 30.0,
      "is_active": true
    },
    {
      "address": "0x456...",
      "oracle": "0x789...",
      "name": "Compound USD",
      "tvl": "7000000000000000000000",
      "percentage": 70.0,
      "is_active": true
    }
  ],
  "timestamp": 1674567890
}
```

## Implementation Details

### PPS Calculation Service
```python
class PPSCalculator:
    def __init__(self, web3_provider, contract_addresses):
        self.web3 = Web3(Web3.HTTPProvider(web3_provider))
        self.contracts = self._initialize_contracts(contract_addresses)
        
    def get_pps(self, supervault_address):
        """Calculate the price per share for a SuperVault"""
        strategy = self._get_strategy_address(supervault_address)
        total_assets = self.calculate_total_assets(strategy)
        total_shares = self._get_total_shares(supervault_address)
        
        if total_shares == 0:
            return Decimal('1.0')  # Initial PPS value
            
        return Decimal(total_assets) / Decimal(total_shares)
    
    def calculate_total_assets(self, strategy_address):
        """Calculate total assets across all yield sources"""
        yield_sources = self._get_yield_sources_list(strategy_address)
        total_assets = 0
        
        for source_address in yield_sources:
            source_data = self._get_yield_source(strategy_address, source_address)
            if source_data['isActive']:
                tvl = self._get_tvl_by_owner(source_data['oracle'], strategy_address)
                total_assets += tvl
                
        return total_assets
```

### Web3 Integration
```python
def _initialize_contracts(self, contract_addresses):
    """Initialize contract objects with ABIs"""
    contracts = {}
    
    # Load ABIs from config files
    with open('config/abis/SuperVault.json') as f:
        supervault_abi = json.load(f)
    
    with open('config/abis/SuperVaultStrategy.json') as f:
        strategy_abi = json.load(f)
        
    # Initialize contract objects
    contracts['supervault_factory'] = self.web3.eth.contract(
        address=Web3.to_checksum_address(contract_addresses['supervault_factory']),
        abi=supervault_abi
    )
    
    return contracts
```

## Deployment
- Deploy as a containerized service using Docker
- Support for Kubernetes deployment with provided manifests
- Include environment variable configuration for different networks

## Performance and Scalability
- Implement caching to reduce redundant blockchain calls (Redis recommended)
- Support horizontal scaling for high-volume deployments
- Monitor performance metrics using Prometheus (optional)

## Testing
- Unit tests for calculation logic
- Integration tests with mock contract responses
- Load testing to ensure performance under stress

## Security Considerations
- No private keys or sensitive data in the codebase
- Rate limiting to prevent abuse
- Input validation for all API endpoints
- CORS configuration for frontend integration

## Future Enhancements (v2)
- WebSocket support for real-time PPS updates
- Historical PPS charting
- Alerting for significant PPS changes
- Multi-chain support
- Advanced analytics for yield performance
