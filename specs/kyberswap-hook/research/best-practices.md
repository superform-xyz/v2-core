# KyberSwap MetaAggregationRouterV2 Research

## Router Address (All Chains)
```
0x6131B5fae19EA4f9D964eAc0408E4408b66337b5
```
Same deterministic address on: Ethereum, Base, BSC, Arbitrum, Optimism, Polygon, Scroll, Linea, Sonic, Avalanche.

## Primary Swap Function
```solidity
function swap(SwapExecutionParams calldata execution) external payable returns (uint256 returnAmount, uint256 gasUsed);
```

## Struct Definitions
```solidity
struct SwapExecutionParams {
    address callTarget;
    address approveTarget;
    SwapDescriptionV2 desc;
    bytes targetData;
    bytes clientData;
}

struct SwapDescriptionV2 {
    IERC20 srcToken;
    IERC20 dstToken;
    address[] srcReceivers;
    uint256[] srcAmounts;
    address[] feeReceivers;
    uint256[] feeAmounts;
    address dstReceiver;
    uint256 amount;
    uint256 minReturnAmount;
    uint256 flags;
    bytes permit;
}
```

**NOTE**: ABI signature is `swap((address,address,bytes,(address,address,address[],uint256[],address[],uint256[],address,uint256,uint256,uint256,bytes),bytes))`. The field ordering may differ from the struct above (clientData may come before desc). MUST verify from Etherscan verified source.

## Fee/Referral System
- No simple referralCode like Odos
- Fees embedded in SwapDescriptionV2: `srcReceivers[]`, `srcAmounts[]`, `feeReceivers[]`, `feeAmounts[]`
- Configured via API, not on-chain params
- `clientData` field used for partner/referral tracking (emitted in events)

## Flag Constants
```solidity
_PARTIAL_FILL         = 0x01
_REQUIRES_EXTRA_ETH   = 0x02
_SHOULD_CLAIM         = 0x04
_BURN_FROM_MSG_SENDER  = 0x08
_BURN_FROM_TX_ORIGIN   = 0x10
_SIMPLE_SWAP           = 0x20
_FEE_ON_DST            = 0x40
_FEE_IN_BPS            = 0x80
_APPROVE_FUND          = 0x100
```

## Native ETH
Sentinel address: `0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE`

## Integration Flow
API returns fully encoded `swap(SwapExecutionParams)` calldata. Hook should pass raw calldata (1inch pattern).

## Sources
- [Etherscan](https://etherscan.io/address/0x6131b5fae19ea4f9d964eac0408e4408b66337b5)
- [KyberSwap Aggregator Docs](https://docs.kyberswap.com/kyberswap-solutions/kyberswap-aggregator/developer-guides/execute-a-swap-with-the-aggregator-api)
- [KyberSwap Deployment Contracts](https://docs.kyberswap.com/kyberswap-solutions/kyberswap-aggregator/contracts)
