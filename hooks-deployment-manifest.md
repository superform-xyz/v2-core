# Hooks Deployment Manifest — Branch: feat/hook-sizing-manifest

New deployments compared to `dev`. Hooks with identical addresses across chains are deployed via CREATE2.

---

## Cross-chain hooks (same address on all chains where deployed)

The following hooks were newly deployed. Addresses are deterministic (CREATE2) and identical across all supported chains.

| Hook | Address | Chains |
|------|---------|--------|
| ApproveAndDeposit4626VaultHook | 0xba687c9D5113a3B2692fd87b0F389dD5fF402808 | All |
| ApproveAndRequestDeposit7540VaultHook | 0x3D40479c9c9B9f12FC3E08625E13A72AFe27c435 | All |
| CancelDepositRequestWithId7540Hook | 0x05B79c1CCC26019a8d93579818cb6aA586b81AE9 | All |
| CancelRedeemRequestWithId7540Hook | 0x4929d62Dd0c1f418Ff31f4f949571A2820290500 | All |
| ClaimCancelDepositRequestWithId7540Hook | 0x3f96d92Af8b6a8632419DC9a9D7A794FBb3EF38d | All |
| ClaimCancelRedeemRequestWithId7540Hook | 0x436B54df18a0545D0F09aDcb79d795CD65A5de4f | All |
| Deposit4626VaultHook | 0x71761d36cF081A3762E5347b4e3635CeCAd5156b | All |
| Deposit7540VaultHook | 0x70b604978aB85aF6f58Df2F4e7313dFd40525646 | All |
| Redeem4626VaultHook | 0x95C61fE513885E23Bd7DA1f27B1ad9B16AE29f81 | All |
| RedeemWithId7540VaultHook | 0x51580e817988B4b56d839827c78A8F39D38036aA | All |
| RequestDeposit7540VaultHook | 0x6B0Fa663F1276b04E12C463B3002c58cFbD59CB3 | All |
| RequestRedeem7540VaultHook | 0x343Cd015339Be39d62d220313654600BbC24cd08 | All |
| SetOperator7540Hook | 0x3731e9Ca56837a5Fb38753Ad1204Bc578566De4a | All |
| WithdrawWithId7540VaultHook | 0xE03A772E17a8383103Ecd743D1167ACA48f50Bd2 | All |
| ApproveAndSwapKyberSwapHook | 0xcF5419270C9415E44c97E595c505708cfA334C30 | ETH, Base, OP, Unichain, Sonic, Arb, Avax, BNB, Berachain, HyperEVM |
| SwapKyberSwapHook | 0x05c49e05bb8575afdf1142cC95dA6747b069174A | ETH, Base, OP, Unichain, Sonic, Arb, Avax, BNB, Berachain, HyperEVM |
| ApproveAndSwapOdosV3Hook | 0x39a99991c7247E71D7148Db529e720D963103B7F | ETH, Base, OP, Polygon, Sonic, Arb, Avax, BNB |
| SwapOdosV3Hook | 0xA987e92641A5677A65EFAa3c87232b41F3E367ca | ETH, Base, OP, Polygon, Sonic, Arb, Avax, BNB |
| Swap1InchHook | 0xeFA058564f85408D994fC60164e7e32290352D6D | ETH, Base, OP, Gnosis, Unichain, Sonic, Arb, Avax, BNB |
| PendleRouterRedeemHook | 0x8fa3AF97c529FFD964b691b7EF9F8A80158339B4 | ETH, Base, OP, Sonic, Arb, BNB, Berachain, HyperEVM |
| PendleUnifiedHook | 0xbaa1A6e68766158C3849d136DC013aB11929B691 | ETH, Base, OP, Sonic, Arb, BNB, Berachain, HyperEVM |

---

## StargateAdapterV2 (per-chain addresses)

| Chain | Chain ID | Address |
|-------|----------|---------|
| Ethereum | 1 | 0x1F78a177A462c03657f8840C4DC339517bB2A290 |
| Base | 8453 | 0x0d9D81c5b1a8F18BAC35DA6731e80f0425954455 |
| Optimism | 10 | 0x86De11DDfc4F7020983AfF63Aebf46963FA6C921 |
| Gnosis | 100 | 0xD148D44773094020b5FcdfEF68C0eA9B32725703 |
| Unichain | 130 | 0xb8195322D89fC9c5c70B2fB06cD81056AaD26c33 |
| Polygon | 137 | 0x19591d9d5f65AcC108222aDE83422DE0B6f56A61 |
| Sonic | 146 | 0x16F7cDbe7288681e250Fef49985cEd09EE40C3e8 |
| Arbitrum | 42161 | 0xBAc66B6e666C0Ad18DbE401cbFe66A0FE13b6702 |
| Avalanche | 43114 | 0x6955B150192EDa28D7fFD2F7626FabbB712FAcAc |
| BNB | 56 | 0xCCd90d43B005aDE3A687cfE93Ce5f0989380f8d0 |
| Linea | 59144 | 0x452C812790F572C267FB491C73c0F14D9d137921 |
| Berachain | 80094 | 0x279C4028Bbb743D0E0803D61ef4044d3a846988c |
| Stable | 988 | 0x2d8287BfA75EaC73A9D6Dc2321135BB660c929d3 |
| Flare | 14 | 0x70DA113dF37e4ED9A414af8Cb51b6C559fac775b |

---

## Chain-specific swap hooks (non-deterministic addresses)

### Polygon (137)

| Hook | Address |
|------|---------|
| ApproveAndSwapKyberSwapHook | 0x7713BC4d63374B01a48C505c6Ee67425f58E4217 |
| SwapKyberSwapHook | 0x42e99D13CD60b1e6B3dD01e04A47c4868817601f |
| Swap1InchHook | 0xB589f46bBBCd032161fc28Ec0217cb968efaab7e |

### Flare (14)

| Hook | Address |
|------|---------|
| ApproveAndSwapOpenOceanHook | 0x88832253c5BFBD07d37A02E6EDFaa28F6e280227 |
| SwapOpenOceanHook | 0xd4Ca1E1afCD79a932D1933dD161f5211790B42d7 |

### HyperEVM (999)

| Hook | Address |
|------|---------|
| ApproveAndSwapUniswapV3Hook | 0xbC4E2d35F616592FEF5B91CD87E617505855eceB |
| SwapUniswapV3Hook | 0x650df1F828203224A262f047AcA2D03ADc59fD08 |

---

## Linea (59144) — New chain deployment

Full deployment added in this branch (chain did not exist on `dev`).

| Hook | Address |
|------|---------|
| AcrossSendFundsAndExecuteOnDstHook | 0xC1dF31D6b99ED8075eF683e9376b7d72eA49c25a |
| AcrossSendFundsAndExecuteOnDstHookV2 | 0x6698A0A7C126109daE3626C880521d456E42d801 |
| AcrossV3Adapter | 0x8C21534b731335B28b112120FcFf3af9b488A47e |
| AcrossV3AdapterV2 | 0x164bA41e75d4F4dA8F80a900c1c38423Cc5b46Dc |
| ApproveAndAcrossSendFundsAndExecuteOnDstHook | 0x8E98961d60C95Aed559E6C8bFCa21cE5dE44Cd56 |
| ApproveAndAcrossSendFundsAndExecuteOnDstHookV2 | 0x85D7EA3C7fdAD73542a48eFE024a16F9246316b9 |
| ApproveAndCCTPSendHook | 0x8aC95e8c40ce2C6D80Fc79e719bC1aca5c2Bf837 |
| ApproveAndDeposit4626VaultHook | 0xba687c9D5113a3B2692fd87b0F389dD5fF402808 |
| ApproveAndDeposit5115VaultHook | 0x44c7a40f05771FdAEAee61f36902D95cbf593988 |
| ApproveAndRequestDeposit7540VaultHook | 0x3D40479c9c9B9f12FC3E08625E13A72AFe27c435 |
| ApproveAndStargateSendHook | 0xeDDF409516D9E4ba9aC58A7Ea97E1FB1BfeCC027 |
| ApproveAndStargateSendHookV2 | 0xAE3e1e2709D9B580Aa3a9e8BA8e5B9dDA1fbB457 |
| ApproveAndSwapKyberSwapHook | 0xcF5419270C9415E44c97E595c505708cfA334C30 |
| ApproveAndSwapOdosV2Hook | 0x317178952Fc408f909172fCbC02FB19B24A25699 |
| ApproveAndSwapOdosV3Hook | 0x39a99991c7247E71D7148Db529e720D963103B7F |
| ApproveAndSwapUniswapV3Router02Hook | 0x810d3D844924311246E2c0FEBa80Bc97770D62e3 |
| ApproveERC20Hook | 0x8b789980dc6cC7d88E30C442D704646ff7F6d306 |
| BatchTransferFromHook | 0x816d5de8835FB7A003896f486fCce46a6DEBB00A |
| BatchTransferHook | 0x55475fa30E3EEC5996e9eF32B483E30Ed288CcBC |
| CCTPSendHook | 0xb0b329150D07Fb4fCA999396783AD40d8470d8C4 |
| CancelDepositRequest7540Hook | 0x0BBA42ddaa6ef6CCd228BD6270565F87154E921A |
| CancelDepositRequestWithId7540Hook | 0x05B79c1CCC26019a8d93579818cb6aA586b81AE9 |
| CancelRedeemRequest7540Hook | 0x542601AfAEeB2E5dFc7d1F2fEEF5911285f0c2c0 |
| CancelRedeemRequestWithId7540Hook | 0x4929d62Dd0c1f418Ff31f4f949571A2820290500 |
| CircleGatewayAddDelegateHook | 0xa7aE1263fd7D6017770147393CE130f16E1fE2cC |
| CircleGatewayMinterHook | 0x659b720a5E8E08D2c379165D17bA5F74dd104824 |
| CircleGatewayRemoveDelegateHook | 0x00FbC4e3608A26E0d05905759C2A6188fDa0e2Cd |
| CircleGatewayWalletHook | 0x6383d09cF761FeAa4108B65130793c7eDA356dB5 |
| ClaimCancelDepositRequest7540Hook | 0xdf958A047D90b202A7097b5f9B67Bb8CB5285858 |
| ClaimCancelDepositRequestWithId7540Hook | 0x3f96d92Af8b6a8632419DC9a9D7A794FBb3EF38d |
| ClaimCancelRedeemRequest7540Hook | 0x0668f9a638f34928f0bD91588E7B157F0699D594 |
| ClaimCancelRedeemRequestWithId7540Hook | 0x436B54df18a0545D0F09aDcb79d795CD65A5de4f |
| ClaimFailedTransferHook | 0xcb1c54042640eDbb77292845A4f703f8EB1BB7C6 |
| DETHYieldSourceOracle | 0xB42f5282FDa7744129febE296a3325939B7b2B6d |
| DeBridgeCancelOrderHook | 0xc5DbbBe2D8B9ff884a7ed33f1352021CD2b482C9 |
| DeBridgeSendOrderAndExecuteOnDstHook | 0x162225095A384787a257bced9b8893b29C8f1795 |
| DebridgeAdapter | 0x5bE003c2cD2DaCD4Cd23488DB7E74568475a36d8 |
| Deposit4626VaultHook | 0x71761d36cF081A3762E5347b4e3635CeCAd5156b |
| Deposit5115VaultHook | 0x32209A2302865784bC1Dc0bd3C55D0A6eB205851 |
| Deposit7540VaultHook | 0x70b604978aB85aF6f58Df2F4e7313dFd40525646 |
| ERC4626YieldSourceOracle | 0x2412A5d7261995b49D1F3a731F8452641B916994 |
| ERC5115YieldSourceOracle | 0x53Ab533023db9f16e47774109D4Ba57b06A52b10 |
| ERC7540YieldSourceOracle | 0x24aEEB728814aF79aD57305Bec5E328DC10341a0 |
| EthenaCooldownSharesHook | 0x1bD7698cc3E3f4cCF5D6CBC74a611bdDEaB18aeF |
| EthenaUnstakeHook | 0xaEBeEc6548B727fd4f3464B19D99f4676d7e7796 |
| FirelightYieldSourceOracle | 0x211E048350c5b61704245BDABfefe95a1239dfE7 |
| FlatFeeLedger | 0xAb56d09Ad9975116fCeb14970F2fFb3bB0ad683E |
| MarkRootAsUsedHook | 0xE61774Aa87a05fB1B5665158F2b5E0E10C71B5e2 |
| MerklClaimRewardHook | 0x96a7939F94bcd57B031AAe01c1e187f3EBaCCa10 |
| OfframpTokensHook | 0x08BA6FF01e651B0c0A0D99AC66563097da2789f7 |
| PendlePTAmortizedOracle | 0xD64089698f82cbCD91ba5e0422aDFa81D247eB62 |
| PendlePTAmortizedOracleV2 | 0x2185B40476510Ad27d17AF90889CE91BE9282A04 |
| PendlePTYieldSourceOracle | 0xc9Eda6330e1D1F7B91f72e459c85401D96BC48C9 |
| RecordPurchasePendlePTAmortizedOracleHook | 0x771D4fF615F87eA00488a2dbcb70DF98BDA03FA3 |
| RecordPurchasePendlePTAmortizedOracleHookV2 | 0xA0E61eb90817E28aBbb5a40045921B69bb784431 |
| RecordRedemptionPendlePTAmortizedOracleHook | 0xb68a34AF34E64a8b3bB72983088ACeB2fAE326Fc |
| RecordRedemptionPendlePTAmortizedOracleHookV2 | 0x2A4F700923324B14bd546630Fe87B1ee08C89634 |
| Redeem4626VaultHook | 0x95C61fE513885E23Bd7DA1f27B1ad9B16AE29f81 |
| Redeem5115VaultHook | 0x6aB1fD107825F9bB3E079d23508A07486b44e6F5 |
| Redeem7540VaultHook | 0xE165FBBc89a60756F57Cf0E34c04c35Cc1BbA79D |
| RedeemWithId7540VaultHook | 0x51580e817988B4b56d839827c78A8F39D38036aA |
| RequestDeposit7540VaultHook | 0x6B0Fa663F1276b04E12C463B3002c58cFbD59CB3 |
| RequestRedeem7540VaultHook | 0x343Cd015339Be39d62d220313654600BbC24cd08 |
| SetOperator7540Hook | 0x3731e9Ca56837a5Fb38753Ad1204Bc578566De4a |
| SetSlippageHook | 0x6551d0140FFdB28920E5e84DC3DA31f4bfe4364E |
| SpectraMetaVaultOracle | 0x7564485A51213443CdCa944B768c56606A028974 |
| SpectraPTYieldSourceOracle | 0xF7DB5389ED49DfB3F260dB6e3389C7d28076E601 |
| StakingYieldSourceOracle | 0x985A6B8DDD9AacEA06ffbF3fc69DaEF48bC819ce |
| StargateAdapter | 0xb122E2A1484Afe5e16D26e28CDF8f37e0e6D0a44 |
| StargateAdapterV2 | 0x452C812790F572C267FB491C73c0F14D9d137921 |
| StargateSendHook | 0x9AAa3A3e598b57162Dc9C56b45877eC0b77E5F38 |
| StargateSendHookV2 | 0xF7cb3da374DA9fedf102451f59CED8810392f241 |
| SuperDestinationExecutor | 0x6ac58e854798D4aae5989B18ad5a1C0fF17817EF |
| SuperDestinationValidator | 0xADEFF5A0684392C4c273a9C638d1dB8c5dfd0098 |
| SuperExecutor | 0x9cC8EDCC41154aaFC74D261aD3D87140D21F6281 |
| SuperLedger | 0x04916bB42564CdED96E10F55C059d65E4FCb1Be6 |
| SuperLedgerConfiguration | 0x2e2D71289CBA19f831856f85DEC7f194B0165e69 |
| SuperNativePaymaster | 0xEc6b5d04C195EeA62cA2991A7DB94AAB3502eFfd |
| SuperSenderCreator | 0xBC6FB94D2f10A3B4349F592FFA80C4B7C97C1799 |
| SuperValidator | 0xB46b4773C5F53FF941533F5dfEFFD0713f5f9f8E |
| SuperVaultYieldSourceOracle | 0xeEbb42210D8a8B165dCF154b325C588EE8dF149A |
| SuperYieldSourceOracle | 0x98F0682ef39dE9cd6028D91090Be6EdAE129f52D |
| Swap1InchHook | 0xeFA058564f85408D994fC60164e7e32290352D6D |
| SwapKyberSwapHook | 0x05c49e05bb8575afdf1142cC95dA6747b069174A |
| SwapOdosV2Hook | 0xe042fc26d83674561Bf413eb28eeB22A5f86F72D |
| SwapOdosV3Hook | 0xA987e92641A5677A65EFAa3c87232b41F3E367ca |
| SwapUniswapV3Router02Hook | 0x289710aE79bC01b3F87ed996ab6FaE3b7B4f9976 |
| TransferERC20Hook | 0x6031c3953BC12D9Af4651B7ed517190A31a67ca4 |
| TransferHook | 0x0d54e1b4060bBD598eE6ec8F7A587fF1789164E9 |
| Withdraw7540VaultHook | 0x4f46c625e6bad4636CB4B9cc418e9780e5C2ad2b |
| WithdrawWithId7540VaultHook | 0xE03A772E17a8383103Ecd743D1167ACA48f50Bd2 |
| YoYieldSourceOracle | 0x125d43f5F35c032a45aaD41EBE344d5c65D626D4 |
