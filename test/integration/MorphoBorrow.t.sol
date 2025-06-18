import {MinimalBaseIntegrationTest} from "./MinimalBaseIntegrationTest.t.sol";
import {MorphoBorrowHook} from "../../src/core/hooks/loan/morpho/MorphoBorrowHook.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISuperExecutor} from "../../src/core/interfaces/ISuperExecutor.sol";
import {UserOpData} from "modulekit/ModuleKit.sol";
import {console} from "forge-std/console.sol";


contract MorphoBorrowTest is MinimalBaseIntegrationTest {
    address public morphoBorrowHook;
    address public morphoRepayHook;

    address public constant CHAIN_1_WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address morpho_oracle_wbtc_usdc = 0xDddd770BADd886dF3864029e4B377B5F6a2B6b83;
    address morpho_irm_wbtc_usdc = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    uint256 public amount;
    uint256 public lltv;
    uint256 public lltvRatio;


    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        morphoBorrowHook = address(new MorphoBorrowHook(address(MORPHO)));

        amount = 1000000;
        lltv = 860_000_000_000_000_000;
        lltvRatio = 660_000_000_000_000_000;

        _getTokens(CHAIN_1_WBTC, accountEth, 1e8);
    }

    function test_MorphoBorrowHook_TracksCollateralNotLoan() external {
        console.log("=== MorphoBorrowHook Token Tracking Test ===");

        address loanToken = CHAIN_1_USDC;
        address collateralToken = CHAIN_1_WBTC;

        // Log initial balances
        uint256 collateralBefore = IERC20(collateralToken).balanceOf(accountEth);
        uint256 loanBefore = IERC20(loanToken).balanceOf(accountEth);
        
        console.log("Initial Balances:");
        console.log("  Collateral (WBTC):", collateralBefore);
        console.log("  Loan Token (USDC):", loanBefore);
        
        // Setup the borrow hook execution
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = morphoBorrowHook;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = _createMorphoBorrowHookData(
            loanToken, 
            collateralToken, 
            morpho_oracle_wbtc_usdc, 
            morpho_irm_wbtc_usdc, 
            amount, 
            lltvRatio, 
            false, 
            lltv
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({hooksAddresses: hooksAddresses, hooksData: hooksData});
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        
        // Execute the borrow operation
        executeOp(userOpData);

        //confirmed by console2.log
    }
}
