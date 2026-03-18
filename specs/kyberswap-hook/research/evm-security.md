# EVM Security Research: KyberSwap Hook

## 1. KyberSwap Elastic Exploit (Nov 2023) - $47M
- Targeted Elastic AMM pools, NOT the MetaAggregationRouterV2
- Rounding error in tick-based swap mechanism
- Not relevant to our aggregator integration

## 2. DEX Aggregator Calldata Manipulation
- SwapNet + Aperture Finance ($17M) - arbitrary call vulnerability
- Attacker replaced router address with token address in user-controlled calldata
- Low-level call executed with attacker-controlled params
- **Mitigation**: Validate callTarget/approveTarget in inspect(), never allow arbitrary targets

## 3. Attack Surface for KyberSwap Hook

### Approval Front-Running
- ERC20 approve race condition (SWC-114)
- USDT requires approve(0) before approve(amount)
- **Mitigation**: approve(0) -> approve(amount) -> swap -> approve(0) pattern (already used in Odos)

### Calldata Manipulation
- Off-chain API returns swap calldata, could be tampered
- Key fields to validate: dstReceiver, dstToken, minReturnAmount
- **Mitigation**: Decode and validate key fields from txData in _validateTxData()

### Router Trust Model
- MetaAggregationRouterV2 has `callTarget` and `approveTarget` fields
- `approveTarget` may differ from router address
- **Mitigation**: inspect() returns both addresses for whitelisting

### Fee Receiver Manipulation
- srcReceivers/feeReceivers arrays in SwapDescriptionV2 could redirect funds
- **Mitigation**: Fee configuration done at API level, validated by off-chain bundler

### Partial Fill Risk
- `_PARTIAL_FILL` flag (0x01) allows incomplete swaps
- **Mitigation**: Disallow partial fills in hook validation (check flags & 0x01 == 0)

## 4. Recommended Security Patterns
1. approve(0) -> approve(amount) -> swap -> approve(0) for ApproveAndSwap
2. Balance delta tracking via pre/post execute (existing pattern)
3. Validate dstReceiver == account
4. Validate minReturnAmount > 0
5. Disallow _PARTIAL_FILL flag
6. Return callTarget and approveTarget from inspect() for whitelisting
7. Non-zero router address check in constructor
