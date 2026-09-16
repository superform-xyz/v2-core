// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20YieldSourceOracle } from "../../../src/accounting/oracles/ERC20YieldSourceOracle.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

/// @title ERC20YieldSourceOracleBSCFork
/// @notice Fork tests for ERC20YieldSourceOracle against the real BSC tokenized stocks the oracle
///         was built for (SuperMAG7 yield sources, addresses from supervault-pricing
///         fair_price_configs.json chain 56). Proves identity semantics hold against live BEP20
///         bytecode: metadata passthrough, PPS = 10^decimals, balance/TVL reads, fee bypass, and
///         batch behavior across the whole token set.
/// @dev Public BSC dataseed nodes are not archival, so the fork runs at latest (no pinned block).
///      Assertions are live-state-robust: exact where the value is an oracle invariant, non-zero
///      where it depends on market state (supplies, holder balances).
contract ERC20YieldSourceOracleBSCFork is Test {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address public constant AAPLB = 0x431a3BEE82E2ca41e49895CbECE5bB0F76A89b7A;
    address public constant MSFTB = 0x80106cb3EAD06659A5ad19DF39D9b4733863B9b0;
    address public constant AMZNB = 0x1a4b499833A79A09ad7Cf1D42D7DacF71e92eb00;
    address public constant NVDAB = 0x02Fca66C1D1aFB4E2A7884261eB00F63598a7436;
    address public constant GOOGLB = 0x3F53De71c126BdaBAe20f9cD64848d317f6C3238;
    address public constant METAB = 0x7425889FE94F9d693E8daefE88BCCed6AcFEf4c0;
    address public constant TSLAB = 0x5b1910eAaD6450E50f816082Aa078C41F10C292f;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    ERC20YieldSourceOracle public oracle;
    address[] public tokens;
    string[] public symbols;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-dataseed.bnbchain.org")));

        SuperLedgerConfiguration ledgerConfig = new SuperLedgerConfiguration();
        oracle = new ERC20YieldSourceOracle(address(ledgerConfig));

        tokens = new address[](7);
        tokens[0] = AAPLB;
        tokens[1] = MSFTB;
        tokens[2] = AMZNB;
        tokens[3] = NVDAB;
        tokens[4] = GOOGLB;
        tokens[5] = METAB;
        tokens[6] = TSLAB;

        symbols = new string[](7);
        symbols[0] = "AAPLB";
        symbols[1] = "MSFTB";
        symbols[2] = "AMZNB";
        symbols[3] = "NVDAB";
        symbols[4] = "GOOGLB";
        symbols[5] = "METAB";
        symbols[6] = "TSLAB";
    }

    /*//////////////////////////////////////////////////////////////
                        METADATA & PRICE PER SHARE
    //////////////////////////////////////////////////////////////*/

    function test_fork_allTokensAreLiveContracts() public view {
        for (uint256 i; i < tokens.length; ++i) {
            assertGt(tokens[i].code.length, 0, symbols[i]);
            // canonical-entry-point sanity: no duplicate addresses in the whitelist candidate set
            for (uint256 j = i + 1; j < tokens.length; ++j) {
                assertNotEq(tokens[i], tokens[j]);
            }
        }
    }

    function test_fork_decimalsPassthrough() public view {
        for (uint256 i; i < tokens.length; ++i) {
            uint8 tokenDecimals = IERC20Metadata(tokens[i]).decimals();
            assertEq(oracle.decimals(tokens[i]), tokenDecimals, symbols[i]);
            // All B-tokens are 18-decimals today; a change here is a corporate-action red flag
            assertEq(tokenDecimals, 18, symbols[i]);
        }
    }

    function test_fork_symbolMatchesExpected() public view {
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(IERC20Metadata(tokens[i]).symbol(), symbols[i]);
        }
    }

    function test_fork_pricePerShareIsIdentity() public view {
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(oracle.getPricePerShare(tokens[i]), 1e18, symbols[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          IDENTITY CONVERTERS
    //////////////////////////////////////////////////////////////*/

    function test_fork_identityConverters() public view {
        uint256[3] memory amounts = [uint256(0), 1e18, type(uint256).max];
        for (uint256 a; a < amounts.length; ++a) {
            uint256 amount = amounts[a];
            for (uint256 i; i < tokens.length; ++i) {
                assertEq(oracle.getShareOutput(tokens[i], address(0), amount), amount, symbols[i]);
                assertEq(oracle.getWithdrawalShareOutput(tokens[i], address(0), amount), amount, symbols[i]);
                assertEq(oracle.getAssetOutput(tokens[i], address(0), amount), amount, symbols[i]);
            }
        }
    }

    function test_fork_feeBypass_getAssetOutputWithFees() public view {
        uint256[3] memory amounts = [uint256(0), 1e18, type(uint256).max];
        for (uint256 a; a < amounts.length; ++a) {
            uint256 amount = amounts[a];
            for (uint256 i; i < tokens.length; ++i) {
                assertEq(
                    oracle.getAssetOutputWithFees(bytes32(0), tokens[i], address(0), address(this), amount),
                    amount,
                    symbols[i]
                );
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                          BALANCES & TVL
    //////////////////////////////////////////////////////////////*/

    function test_fork_getTVLIsGlobalTotalSupply() public view {
        for (uint256 i; i < tokens.length; ++i) {
            uint256 supply = IERC20(tokens[i]).totalSupply();
            assertEq(oracle.getTVL(tokens[i]), supply, symbols[i]);
            assertGt(supply, 0, symbols[i]);
        }
    }

    function test_fork_balanceOfOwner_dealAndRead() public {
        address strategy = makeAddr("superMAG7Strategy");
        for (uint256 i; i < tokens.length; ++i) {
            uint256 amount = (i + 1) * 1e18;
            deal(tokens[i], strategy, amount);
            assertEq(oracle.getBalanceOfOwner(tokens[i], strategy), amount, symbols[i]);
            // identity PPS: owner TVL == raw balance
            assertEq(oracle.getTVLByOwnerOfShares(tokens[i], strategy), amount, symbols[i]);
        }
    }

    function test_fork_balanceOfOwner_zeroForFreshAddress() public {
        address fresh = makeAddr("freshOwner");
        for (uint256 i; i < tokens.length; ++i) {
            assertEq(oracle.getBalanceOfOwner(tokens[i], fresh), 0, symbols[i]);
        }
    }

    function test_fork_realTransferTracksBalance() public {
        address strategy = makeAddr("superMAG7Strategy");
        address receiver = makeAddr("receiver");
        deal(NVDAB, strategy, 10e18);

        vm.prank(strategy);
        IERC20(NVDAB).transfer(receiver, 4e18);

        // live BEP20 transfer semantics: no fee-on-transfer, oracle reads track 1:1
        assertEq(oracle.getBalanceOfOwner(NVDAB, strategy), 6e18);
        assertEq(oracle.getBalanceOfOwner(NVDAB, receiver), 4e18);
        assertEq(oracle.getTVLByOwnerOfShares(NVDAB, strategy) + oracle.getTVLByOwnerOfShares(NVDAB, receiver), 10e18);
    }

    /*//////////////////////////////////////////////////////////////
                            BATCH VIEWS
    //////////////////////////////////////////////////////////////*/

    function test_fork_getPricePerShareMultiple_wholeMag7Set() public view {
        uint256[] memory pps = oracle.getPricePerShareMultiple(tokens);
        assertEq(pps.length, tokens.length);
        for (uint256 i; i < pps.length; ++i) {
            assertEq(pps[i], 1e18, symbols[i]);
        }
    }

    function test_fork_getTVLMultiple_wholeMag7Set() public view {
        uint256[] memory tvls = oracle.getTVLMultiple(tokens);
        assertEq(tvls.length, tokens.length);
        for (uint256 i; i < tvls.length; ++i) {
            assertEq(tvls[i], IERC20(tokens[i]).totalSupply(), symbols[i]);
        }
    }

    function test_fork_getTVLByOwnerOfSharesMultiple_isolated() public {
        address strategy = makeAddr("superMAG7Strategy");
        for (uint256 i; i < tokens.length; ++i) {
            deal(tokens[i], strategy, (i + 1) * 1e18);
        }

        address[][] memory owners = new address[][](tokens.length);
        for (uint256 i; i < tokens.length; ++i) {
            owners[i] = new address[](1);
            owners[i][0] = strategy;
        }

        (uint256[][] memory userTvls, bool[][] memory succeeded) = oracle.getTVLByOwnerOfSharesMultiple(tokens, owners);
        for (uint256 i; i < tokens.length; ++i) {
            assertTrue(succeeded[i][0], symbols[i]);
            assertEq(userTvls[i][0], (i + 1) * 1e18, symbols[i]);
        }
    }

    function test_fork_getTVLByOwnerOfSharesMultiple_brokenEntryIsolated() public {
        address strategy = makeAddr("superMAG7Strategy");
        deal(AAPLB, strategy, 5e18);

        // one non-token entry in the middle must not poison the isolated batch
        address[] memory sources = new address[](3);
        sources[0] = AAPLB;
        sources[1] = makeAddr("notAToken");
        sources[2] = TSLAB;

        address[][] memory owners = new address[][](3);
        for (uint256 i; i < 3; ++i) {
            owners[i] = new address[](1);
            owners[i][0] = strategy;
        }

        (uint256[][] memory userTvls, bool[][] memory succeeded) = oracle.getTVLByOwnerOfSharesMultiple(sources, owners);
        assertTrue(succeeded[0][0]);
        assertEq(userTvls[0][0], 5e18);
        assertFalse(succeeded[1][0]);
        assertEq(userTvls[1][0], 0);
        assertTrue(succeeded[2][0]);
        assertEq(userTvls[2][0], 0);
    }
}
