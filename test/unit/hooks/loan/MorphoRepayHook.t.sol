// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ISuperHook } from "../../../../src/core/interfaces/ISuperHook.sol";
import { MarketParamsLib } from "../../../../src/vendor/morpho/MarketParamsLib.sol";
import { MorphoRepayHook } from "../../../../src/core/hooks/loan/morpho/MorphoRepayHook.sol";
import { IMorphoBase, IMorphoStaticTyping, Id, MarketParams, IMorpho } from "../../../../src/vendor/morpho/IMorpho.sol";
import { Helpers } from "../../../utils/Helpers.sol";

contract MorphoRepayHookTest is Helpers {
    using MarketParamsLib for MarketParams;

    MorphoRepayHook public hook;
    address public loanToken;
    address public collateralToken;
    address public oracleAddress;
    address public irmAddress;
    address public morphoAddress;
    uint256 public amount;
    uint256 public lltv;

    MarketParams public marketParams;
    Id public marketId;

    // Interfaces pointing to the MORPHO address
    IMorphoBase public morphoBase;
    IMorpho public morphoInterface;
    IMorphoStaticTyping public morphoStaticTyping;

    function setUp() public {
        // Initialize hook
        hook = new MorphoRepayHook(MORPHO);

        loanToken = 0x4200000000000000000000000000000000000006;
        collateralToken = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

        oracleAddress = MORPHO_ORACLE;
        irmAddress = MORPHO_IRM;
        morphoAddress = MORPHO;
        amount = 100e6;
        lltv = 860_000_000_000_000_000;
    }

    // --- Test Cases ---

    function test_Constructor() public view {
        assertEq(hook.morpho(), morphoAddress, "Morpho address mismatch");
        assertEq(address(hook.morphoBase()), morphoAddress, "MorphoBase interface mismatch");
        assertEq(address(hook.morphoInterface()), morphoAddress, "Morpho interface mismatch");
        assertEq(address(hook.morphoStaticTyping()), morphoAddress, "MorphoStaticTyping interface mismatch");
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING), "HookType mismatch");
    }

    function test_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MorphoRepayHook(address(0));
    }

    function test_Build_RevertIf_InvalidAddressesInParams() public {
        // Test invalid loan token (address(0))
        address invalidLoanToken = address(0);
        bytes memory dataInvalidLoan = _encodeData(
            invalidLoanToken, address(collateralToken), oracleAddress, irmAddress, amount, lltv, false, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), dataInvalidLoan);

        // Test invalid collateral token (address(0))
        address invalidCollateralToken = address(0);
        bytes memory dataInvalidCollateral = _encodeData(
            address(loanToken), invalidCollateralToken, oracleAddress, irmAddress, amount, lltv, false, false
        );
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), dataInvalidCollateral);
    }

    // --- Helper Functions ---

    /// @dev Encodes data for the MorphoRepayHook using the globally defined marketParams.
    function _encodeData(
        address _loanToken,
        address _collateralToken,
        address _oracle,
        address _irm,
        uint256 _amount,
        uint256 _lltv,
        bool usePrevHook,
        bool isFullRepayment
    )
        internal
        pure
        returns (bytes memory)
    {
        return _encodeDataWithParams(
            _loanToken, _collateralToken, _oracle, _irm, _amount, _lltv, usePrevHook, isFullRepayment
        );
    }

    /// @dev Encodes data for the MorphoRepayHook using specific MarketParams.
    function _encodeDataWithParams(
        address _loanToken,
        address _collateralToken,
        address _oracle,
        address _irm,
        uint256 _amount,
        uint256 _lltv,
        bool usePrevHook,
        bool isFullRepayment
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            _loanToken, // address loanToken (0-19)
            _collateralToken, // address collateralToken (20-39)
            _oracle, // address oracle (40-59)
            _irm, // address irm (60-79)
            _amount, // uint256 amount (80-111)
            _lltv, // uint256 lltv (112-143)
            usePrevHook, // bool usePrevHookAmount (144)
            isFullRepayment // bool isFullRepayment (145)
        );
    }
}
