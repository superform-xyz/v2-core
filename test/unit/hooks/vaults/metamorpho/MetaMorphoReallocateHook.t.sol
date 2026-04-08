// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MetaMorphoReallocateHook } from
    "../../../../../src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol";
import { ISuperHook, ISuperHookContextAware } from "../../../../../src/interfaces/ISuperHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { IMetaMorpho, MarketAllocation } from "../../../../../src/vendor/morpho/IMetaMorpho.sol";
import { MarketParams } from "../../../../../src/vendor/morpho/IMorpho.sol";

contract MetaMorphoReallocateHookTest is Helpers {
    using BytesLib for bytes;

    MetaMorphoReallocateHook public hook;

    address public vault;
    MarketParams public marketA;
    MarketParams public marketB;

    function setUp() public {
        hook = new MetaMorphoReallocateHook();
        vault = makeAddr("metaMorphoVault");

        marketA = MarketParams({
            loanToken: makeAddr("loanTokenA"),
            collateralToken: makeAddr("collateralTokenA"),
            oracle: makeAddr("oracleA"),
            irm: makeAddr("irmA"),
            lltv: 0.8e18
        });

        marketB = MarketParams({
            loanToken: makeAddr("loanTokenB"),
            collateralToken: makeAddr("collateralTokenB"),
            oracle: makeAddr("oracleB"),
            irm: makeAddr("irmB"),
            lltv: 0.9e18
        });
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.SUB_TYPE(), HookSubTypes.MISC);
    }

    /*//////////////////////////////////////////////////////////////
                            BUILD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_SingleAllocation() public view {
        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 1000e6 });

        bytes memory data = _encodeData(vault, false, 0, allocations);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        // preExecute + hook execution + postExecute = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, vault);
        assertEq(executions[1].value, 0);

        bytes memory expectedCalldata = abi.encodeCall(IMetaMorpho.reallocate, (allocations));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_MultipleAllocations() public view {
        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 500e6 });
        allocations[1] = MarketAllocation({ marketParams: marketB, assets: 500e6 });

        bytes memory data = _encodeData(vault, false, 0, allocations);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, vault);

        bytes memory expectedCalldata = abi.encodeCall(IMetaMorpho.reallocate, (allocations));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_RevertIf_ZeroVaultAddress() public {
        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 1000e6 });

        bytes memory data = _encodeData(address(0), false, 0, allocations);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_RevertIf_EmptyAllocations() public {
        MarketAllocation[] memory allocations = new MarketAllocation[](0);

        bytes memory data = _encodeData(vault, false, 0, allocations);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    /*//////////////////////////////////////////////////////////////
                        USE PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_UsePrevHookAmount_ReplacesAtIndex() public {
        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 500e6 });
        allocations[1] = MarketAllocation({ marketParams: marketB, assets: 0 }); // to be replaced

        uint256 prevHookOutput = 750e6;
        address prevHook = makeAddr("prevHook");
        address account = makeAddr("account");

        vm.mockCall(
            prevHook,
            abi.encodeWithSelector(bytes4(keccak256("getOutAmount(address)")), account),
            abi.encode(prevHookOutput)
        );

        bytes memory data = _encodeData(vault, true, 1, allocations);
        Execution[] memory executions = hook.build(prevHook, account, data);

        MarketAllocation[] memory expectedAllocations = new MarketAllocation[](2);
        expectedAllocations[0] = MarketAllocation({ marketParams: marketA, assets: 500e6 });
        expectedAllocations[1] = MarketAllocation({ marketParams: marketB, assets: prevHookOutput });

        bytes memory expectedCalldata = abi.encodeCall(IMetaMorpho.reallocate, (expectedAllocations));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_UsePrevHookAmount_IndexZero() public {
        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 0 }); // to be replaced
        allocations[1] = MarketAllocation({ marketParams: marketB, assets: 500e6 });

        uint256 prevHookOutput = 300e6;
        address prevHook = makeAddr("prevHook");
        address account = makeAddr("account");

        vm.mockCall(
            prevHook,
            abi.encodeWithSelector(bytes4(keccak256("getOutAmount(address)")), account),
            abi.encode(prevHookOutput)
        );

        bytes memory data = _encodeData(vault, true, 0, allocations);
        Execution[] memory executions = hook.build(prevHook, account, data);

        MarketAllocation[] memory expectedAllocations = new MarketAllocation[](2);
        expectedAllocations[0] = MarketAllocation({ marketParams: marketA, assets: prevHookOutput });
        expectedAllocations[1] = MarketAllocation({ marketParams: marketB, assets: 500e6 });

        bytes memory expectedCalldata = abi.encodeCall(IMetaMorpho.reallocate, (expectedAllocations));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_RevertIf_PrevHookAmountIndex_OutOfBounds() public {
        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 500e6 });
        allocations[1] = MarketAllocation({ marketParams: marketB, assets: 500e6 });

        address prevHook = makeAddr("prevHook");
        address account = makeAddr("account");

        // Index 2 is out of bounds for a 2-element array
        bytes memory data = _encodeData(vault, true, 2, allocations);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(prevHook, account, data);
    }

    /*//////////////////////////////////////////////////////////////
                            INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspect() public view {
        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 1000e6 });

        bytes memory data = _encodeData(vault, false, 0, allocations);
        bytes memory inspectionResult = hook.inspect(data);

        assertEq(BytesLib.toAddress(inspectionResult, 0), vault);
    }

    /*//////////////////////////////////////////////////////////////
                        DECODE USE PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DecodeUsePrevHookAmount_True() public view {
        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 1000e6 });

        bytes memory data = _encodeData(vault, true, 0, allocations);
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeUsePrevHookAmount_False() public view {
        MarketAllocation[] memory allocations = new MarketAllocation[](1);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 1000e6 });

        bytes memory data = _encodeData(vault, false, 0, allocations);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    /*//////////////////////////////////////////////////////////////
                            DATA ENCODING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DataEncodingDecoding() public view {
        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: 500e6 });
        allocations[1] = MarketAllocation({ marketParams: marketB, assets: 500e6 });

        bytes memory data = _encodeData(vault, true, 1, allocations);

        // Verify vault address extraction
        assertEq(BytesLib.toAddress(data, 32), vault);

        // Verify usePrevHookAmount
        assertEq(data[52] != 0, true);

        // Verify prevHookAmountIndex
        assertEq(BytesLib.toUint8(data, 53), 1);

        // Verify allocations decoding
        bytes memory allocationsData = BytesLib.slice(data, 54, data.length - 54);
        MarketAllocation[] memory decoded = abi.decode(allocationsData, (MarketAllocation[]));
        assertEq(decoded.length, 2);
        assertEq(decoded[0].assets, 500e6);
        assertEq(decoded[1].assets, 500e6);
        assertEq(decoded[0].marketParams.loanToken, marketA.loanToken);
        assertEq(decoded[1].marketParams.loanToken, marketB.loanToken);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Build(address _vault, uint256 assets1, uint256 assets2) public view {
        vm.assume(_vault != address(0));
        vm.assume(assets1 > 0);
        vm.assume(assets2 > 0);

        MarketAllocation[] memory allocations = new MarketAllocation[](2);
        allocations[0] = MarketAllocation({ marketParams: marketA, assets: assets1 });
        allocations[1] = MarketAllocation({ marketParams: marketB, assets: assets2 });

        bytes memory data = _encodeData(_vault, false, 0, allocations);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, _vault);
        assertEq(executions[1].value, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _encodeData(
        address _vault,
        bool _usePrevHookAmount,
        uint8 _prevHookAmountIndex,
        MarketAllocation[] memory _allocations
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory placeholder = new bytes(32);
        bytes memory allocationsData = abi.encode(_allocations);

        return bytes.concat(
            placeholder,
            abi.encodePacked(_vault),
            abi.encodePacked(_usePrevHookAmount ? uint8(1) : uint8(0)),
            abi.encodePacked(_prevHookAmountIndex),
            allocationsData
        );
    }
}
