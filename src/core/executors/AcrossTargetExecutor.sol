// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { INexusFactory } from "../../vendor/nexus/INexusFactory.sol";
import { IAcrossV3Receiver } from "../../vendor/bridges/across/IAcrossV3Receiver.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IValidator } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { IERC7579Account } from "modulekit/accounts/common/interfaces/IERC7579Account.sol";

// Superform
import { SuperExecutorBase } from "./SuperExecutorBase.sol";
import { IAcrossTargetExecutor } from "../interfaces/IAcrossTargetExecutor.sol";

/// @title AcrossTargetExecutor
/// @author Superform Labs
/// @notice Executor for destination chains of Superform
/// @notice This contract acts as a gateway for receiving funds from the Across Protocol
/// @notice and executing associated user operations.
/// @dev Example Scenario:
/// @custom:example
/// User wants to transfer 100 USDC from Ethereum to Arbitrum and execute an operation:
/// 1. User initiates transfer on Ethereum (source chain)
/// 2. Across Protocol processes this as two separate transactions (TX1 and TX2) on Arbitrum
///
/// Two possible cases can occur:
///
/// Case 1 (Rare) - User receives new funds between TX1 and TX2:
/// - TX1 arrives first and attempts to execute with 100 USDC
/// - If 100 USDC is available (from other sources), TX1 succeeds
/// - TX2 arrives second but fails due to nonce change from TX1
///
/// Case 2 (Typical) - No new funds between TX1 and TX2:
/// - TX1 arrives first but silently fails  as 100 USDC not yet available
/// - TX2 arrives second with the 100 USDC and succeeds
/// @dev Also in cross-chain rebalancing operations to receive funds and execute actions
/// @custom:example
///     Cross-chain Rebalance Flow Example:
///     1. Chain A: User initiates withdrawal from Superform
///     2. Chain A: Funds are bridged via Across
///     3. Chain B: This contract receives funds + message
///     4. Chain B: Contract transfers tokens to user's account
///     5. Chain B: Executes deposit into new Superform
contract AcrossTargetExecutor is SuperExecutorBase, IAcrossV3Receiver, IAcrossTargetExecutor {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    address public immutable acrossSpokePool;
    address public immutable superDestinationValidator;
    INexusFactory public immutable nexusFactory;
    uint256 public nonce;

    // https://docs.uniswap.org/contracts/v3/reference/periphery/interfaces/external/IERC1271
    bytes4 constant SIGNATURE_MAGIC_VALUE = bytes4(0x1626ba7e);
    uint256 constant EMPTY_EXECUTION_LENGTH = 228; //saves decoding gas

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_ACCOUNT();
    error INVALID_SIGNATURE();
    error ADDRESS_NOT_ACCOUNT();

    constructor(address registry_, address acrossSpokePool_, address superDestinationValidator_, address nexusFactory_) SuperExecutorBase(registry_) {
        if (acrossSpokePool_ == address(0) || superDestinationValidator_ == address(0) || nexusFactory_ == address(0)) revert ADDRESS_NOT_VALID();
        acrossSpokePool = acrossSpokePool_;
        superDestinationValidator = superDestinationValidator_;
        nexusFactory = INexusFactory(nexusFactory_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function name() external pure override returns (string memory) {
        return "AcrossTargetExecutor";
    }

    function version() external pure override returns (string memory) {
        return "0.0.1";
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAcrossV3Receiver
    function handleV3AcrossMessage(
        address tokenSent,
        uint256 amount,
        address, //relayer; not used
        bytes memory message
    )
        external
    {
        if (msg.sender != acrossSpokePool) revert INVALID_SENDER();

        // @dev sigData needs the following fields:
        //      - uint48 validUntil
        //      - bytes32 merkleRoot
        //      - bytes32[] proof
        //      - bytes signature
        // @dev executor calldata represents the ExecutorEntry object (hooksAddresses, hooksData)
        (bytes memory initData, bytes memory executorCalldata, bytes memory sigData, address account, uint256 intentAmount) = abi.decode(message, (bytes, bytes, bytes, address, uint256));

        if (account.code.length > 0) {
            string memory accountId = IERC7579Account(account).accountId();
            if (bytes(accountId).length == 0) revert ADDRESS_NOT_ACCOUNT();
        }
        // @dev we need to create the account   
        if (initData.length > 0 && account.code.length == 0) {
            (bytes memory factoryInitData, bytes32 salt) = abi.decode(initData, (bytes, bytes32));
            address computedAddress = nexusFactory.computeAccountAddress(factoryInitData, salt);
            account = nexusFactory.createAccount(factoryInitData, salt);
            if (account != computedAddress) revert INVALID_ACCOUNT();
        }

        
        uint256 _nonce = nonce;
        nonce++;

        // @dev validate execution
        bytes memory destinationData = abi.encode(_nonce, executorCalldata, uint64(block.chainid), account);
        bytes4 validationResult = IValidator(superDestinationValidator).isValidSignatureWithSender(account, bytes32(0), abi.encode(sigData, destinationData));
        if (validationResult != SIGNATURE_MAGIC_VALUE) revert INVALID_SIGNATURE();



        // @dev send tokens to the smart account
        IERC20 token = IERC20(tokenSent);
        token.safeTransfer(account, amount);

        // @dev check if the account has sufficient balance before proceeding
        if (intentAmount != 0 && token.balanceOf(account) < intentAmount) {
            emit AcrossTargetExecutorReceivedButNotEnoughBalance(account);
            return;
        }

        // check if we have hooks
        if (executorCalldata.length <= EMPTY_EXECUTION_LENGTH) {
            emit AcrossTargetExecutorReceivedButNoHooks();
            return;
        }

        // @dev _execute -> executeFromExecutor -> SuperExecutorBase.execute
        Execution[] memory execs = new Execution[](1);
        execs[0] = Execution({
            target: address(this),
            value: 0,
            callData: executorCalldata
        });
        _execute(account, execs);

        emit AcrossTargetExecutorExecuted(account);
    }
}
