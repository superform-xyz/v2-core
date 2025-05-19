// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// external
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vm} from "forge-std/Vm.sol";

// Superform
import {Constants} from "./Constants.sol";

abstract contract Helpers is Test, Constants {
    address constant VM_ADDR = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;

    address public user1;
    address public user2;
    address public user3;
    address public MANAGER;
    address public TREASURY;
    address public SUPER_BUNDLER;
    address public ACROSS_RELAYER;
    address public SV_MANAGER;
    address public STRATEGIST;
    address public EMERGENCY_ADMIN;
    address public VALIDATOR;
    /*//////////////////////////////////////////////////////////////
                                 EIP-7702 HELPER METHODS
    //////////////////////////////////////////////////////////////*/

    modifier add7702Precompile(address eoa_, bytes memory code_) {
        // https://book.getfoundry.sh/cheatcodes/etch
        vm.etch(eoa_, code_);
        _;
        vm.etch(eoa_, "");
    }

    modifier is7702StorageCompliant(address eoa_) {
        //https://book.getfoundry.sh/cheatcodes/start-state-diff-recording?highlight=startStateDiffRecording#startstatediffrecording

        vm.startStateDiffRecording();
        _;
        Vm.AccountAccess[] memory records = vm.stopAndReturnStateDiff();
        //https://book.getfoundry.sh/cheatcodes/stop-and-return-state-diff?highlight=stopAndReturnStateDiff#stopandreturnstatediff

        for (uint256 i = 0; i < records.length; i++) {
            Vm.AccountAccess memory record = records[i];
            if (record.account == eoa_) {
                assertEq(record.storageAccesses.length, 0);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 MERKLE TREE HELPER METHODS
    //////////////////////////////////////////////////////////////*/
    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    /*//////////////////////////////////////////////////////////////
                                 GENERIC HELPER METHODS
    //////////////////////////////////////////////////////////////*/
    function _bound(uint256 amount_) internal pure returns (uint256) {
        amount_ = bound(amount_, SMALL, LARGE);
        return amount_;
    }

    function _resetCaller(address from_) internal {
        vm.stopPrank();
        vm.startPrank(from_);
    }

    function approveErc20(address token_, address from_, address operator_, uint256 amount_) internal {
        _resetCaller(from_);
        IERC20(token_).approve(operator_, amount_);
    }

    function _getTokens(address token_, address to_, uint256 amount_) internal {
        deal(token_, to_, amount_);
    }

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, hash) // Store into scratch space for keccak256.
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32") // 28 bytes.
            result := keccak256(0x04, 0x3c) // `32 * 2 - (32 - 28) = 60 = 0x3c`.
        }
    }
    /*//////////////////////////////////////////////////////////////
                                 DEPLOYERS
    //////////////////////////////////////////////////////////////*/

    function _deployAccount(uint256 key_, string memory name_) internal returns (address) {
        address _user = vm.addr(key_);
        vm.deal(_user, LARGE);
        vm.label(_user, name_);
        return _user;
    }

    function envOr(string memory name, string memory defaultValue) public view returns (string memory value) {
        return Vm(VM_ADDR).envOr(name, defaultValue);
    }

    function startStateDiffRecording() public {
        Vm(VM_ADDR).startStateDiffRecording();
    }

    function envOr(string memory name, bool defaultValue) public view returns (bool value) {
        return Vm(VM_ADDR).envOr(name, defaultValue);
    }
}
