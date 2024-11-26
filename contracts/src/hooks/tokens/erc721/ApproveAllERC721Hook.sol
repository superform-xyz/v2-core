// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";
import { IERC721 } from "@openzeppelin/contracts/interfaces/IERC721.sol";

// Superform
import { IHook } from "src/interfaces/IHook.sol";
import { BaseHook } from "src/utils/BaseHook.sol";

contract ApproveAllERC721Hook is BaseHook, IHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    function totalOps() external pure override returns (uint256) {
        return 1;
    }

    function build(bytes memory data) external pure override returns (Execution[] memory executions) {
        (address token, address spender, bool approved) = abi.decode(data, (address, address, bool));

        if (token == address(0) || spender == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: token,
            value: 0,
            callData: abi.encodeCall(IERC721.setApprovalForAll, (spender, approved))
        });
    }
}
