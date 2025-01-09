// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import {ERC7579ValidatorBase} from "modulekit/Modules.sol";
import {PackedUserOperation} from "modulekit/external/ERC4337.sol";

contract MockValidatorModule is ERC7579ValidatorBase {
    uint256 public val;
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    function name() external pure returns (string memory) {
        return "MockValidatorModule";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function onInstall(bytes calldata) external {}
    function onUninstall(bytes calldata) external {}

    function validateUserOp(PackedUserOperation calldata _userOp, bytes32 _userOpHash)
        external
        override
        returns (ValidationData)
    {
        val = 1e18;
        return _verifySignature(_userOp.sender, _userOpHash, _userOp.signature);
    }

    function isValidSignatureWithSender(address, bytes32, bytes calldata) external pure override returns (bytes4) {
        return 0x1626ba7e; //ERC1271_MAGIC_VALUE
    }

    function _verifySignature(address, bytes32, bytes calldata) internal pure returns (ValidationData) {
        //sigFailed  - True for signature failure, false for success.
        //validUntil - Last timestamp this UserOperation is valid (or zero for infinite)
        //validAfter - First timestamp this UserOperation is valid.
        return _packValidationData(false, 0, 0);
    }
}
