# Framework Documentation Research: ERC-7540 Oracle

## Date: 2026-04-29

---

## 1. Foundry Invariant Testing

### Handler Pattern

Handler contracts wrap the system under test with constrained entry points. The fuzzer calls handler functions (not the target directly).

```solidity
contract Handler is Test {
    uint256 public ghost_totalDeposited;

    function hDeposit(uint256 assets) external {
        assets = bound(assets, 1, type(uint128).max);
        vault.deposit(assets, msg.sender);
        ghost_totalDeposited += assets;
    }
}
```

### Setup

```solidity
function setUp() public {
    // Deploy system + handlers
    targetContract(address(vanillaHandler));
    targetContract(address(centrifugeHandler));
    targetContract(address(yoStyleHandler));
}
```

All `invariant_*` prefixed functions are checked after each call sequence.

### Configuration

Add to `foundry.toml`:
```toml
[invariant]
runs = 256        # Independent test runs
depth = 100       # Calls per run
fail_on_revert = false  # Set true once handlers are stable
shrink_run_limit = 5000
```

Inline per-test override via NatSpec:
```solidity
/// forge-config: default.invariant.runs = 100
/// forge-config: default.invariant.depth = 50
function invariant_pricePerShareMonotonic() public { ... }
```

Run: `forge test --mt invariant`

### Multiple Vaults

Deploy 3 handlers (one per mock vault) and `targetContract()` each. Fuzzer randomly picks actions across all 3.

## 2. SafeERC20 in View-Only Contexts

**Not needed.** The oracle only calls view functions (`balanceOf`, `decimals`, `convertToAssets`, etc.). SafeERC20 is for state-changing operations (`transfer`, `approve`). No existing oracle in the codebase uses SafeERC20.

## 3. Solidity 0.8.30 Try/Catch

### External View Calls

Try/catch works with `view` and `pure` external calls:
```solidity
try IERC7540(vault).pendingRedeemRequest(0, owner) returns (uint256 shares) {
    pendingValue = shares > 0 ? vault.convertToAssets(shares) : 0;
} catch { }
```

### Out-of-Gas Behavior

- External call OOG: reverts with empty return data. Caller retains 1/64th gas (63/64 rule). Bare `catch` catches it.
- Caller OOG after try: entire transaction reverts. Try/catch cannot protect.

### Catch Clause Types

| Clause | Catches |
|--------|---------|
| `catch Error(string memory)` | `revert("msg")`, `require()` |
| `catch Panic(uint256)` | assertion failures, div-by-zero |
| `catch (bytes memory)` | everything with return data |
| `catch` (bare) | everything including empty data (OOG) |

**For the oracle, use bare `catch` — safest for unknown vault behavior.**

### Gotchas

1. ABI decoding failure on success is NOT caught — entire try/catch reverts
2. Try/catch only for external calls
3. Return bomb risk (malicious large revert data) — low risk for trusted vaults

## 4. ERC-7540 Reference Implementations

### Existing Codebase Artifacts

- `src/vendor/vaults/7540/IERC7540.sol` — full interface
- `test/mocks/unused-oracles/ERC7540YieldSourceOracle.sol` — deleted oracle (4626 clone)
- `test/unit/hooks/vaults/7540/ERC7540HookTests.t..sol` — forks Ethereum at block 21,929,476, uses `CHAIN_1_CENTRIFUGE_USDC`

### External References

- [ERC4626-Alliance/ERC-7540-Reference](https://github.com/ERC4626-Alliance/ERC-7540-Reference) — audited reference impl
- [Centrifuge liquidity-pools](https://github.com/centrifuge/liquidity-pools) — most mature production 7540
- [Recon-Fuzz/erc7540-reusable-properties](https://github.com/Recon-Fuzz/erc7540-reusable-properties) — Chimera-compatible invariant properties

### Key Compatibility Note

7540 uses separate share token via ERC-7575 `share()`. Use `IERC7540(vault).share()` then `IERC20(share).balanceOf()`.

## 5. Foundry Fork Testing

### Pattern (from existing codebase)

```solidity
vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), 21_929_476);
```

**Always pin to a specific block number** for determinism and caching.

### Multi-Fork

```solidity
uint256 ethFork = vm.createFork("ethereum", ETH_BLOCK);
uint256 baseFork = vm.createFork("base", BASE_BLOCK);
vm.selectFork(baseFork);
```

### Performance

- Cache at `~/.foundry/cache/rpc/<chain>/<block>/`
- First run: ~7 min. Subsequent: ~0.5 sec.
- Avoid fuzz testing with fork RPC calls (rate limit exhaustion)

## 6. Chimera/Recon Integration

### Can Same Handlers Be Used?

**Yes**, with constraints:
- Only HEVM-compatible cheatcodes (`prank`, `deal`, `warp`, `roll`, `store/load`)
- Foundry-only cheats (`createSelectFork`, `expectRevert`, `expectEmit`, `env*`) won't work on Echidna/Medusa
- Fork-based tests stay Foundry-only; mock-based invariant tests can use Chimera

### Template (create-chimera-app)

```
test/recon/
  Setup.sol          -- deploys contracts (shared)
  TargetFunctions.sol -- handler functions (shared)
  Properties.sol     -- invariant checks (shared)
  CryticToFoundry.sol -- Foundry adapter
  CryticTester.sol   -- Echidna/Medusa adapter
```

### Practical Recommendation

- Write mock-based handlers with HEVM-only cheatcodes (Chimera-compatible)
- Keep fork-based integration tests as Foundry-only
- [Recon-Fuzz/erc7540-reusable-properties](https://github.com/Recon-Fuzz/erc7540-reusable-properties) provides directly relevant 7540 invariants

## Sources

- [Foundry Invariant Testing](https://book.getfoundry.sh/forge/invariant-testing)
- [Foundry Fork Testing](https://book.getfoundry.sh/forge/fork-testing)
- [Foundry Best Practices](https://getfoundry.sh/guides/best-practices/writing-tests/)
- [RareSkills - Invariant Testing](https://rareskills.io/post/invariant-testing-solidity)
- [RareSkills - Try/Catch](https://rareskills.io/post/try-catch-solidity)
- [Chimera Framework](https://book.getrecon.xyz/writing_invariant_tests/chimera_framework.html)
- [create-chimera-app](https://github.com/Recon-Fuzz/create-chimera-app)
