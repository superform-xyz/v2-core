// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Test, console } from "forge-std/Test.sol";

interface IPendlePTAmortizedOracle {
    function getBookValue(address strategy, address market) external view returns (uint256);
    function getPricePerShare(address market) external view returns (uint256);
    function getAssetOutput(address market, address owner, uint256 sharesIn) external view returns (uint256);
    function getTVLByOwnerOfShares(address market, address ownerOfShares) external view returns (uint256);
    function bookValues(address strategy, address market) external view returns (uint128 lastUpdateBookValue, uint64 lastUpdateTime);
    function correctBookValue(address strategy, address market, uint128 newBookValue) external;
    function MANAGER_ROLE() external view returns (bytes32);
    function hasRole(bytes32 role, address account) external view returns (bool);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IPMarket {
    function readTokens() external view returns (address sy, address pt, address yt);
}

interface IStandardizedYield {
    function assetInfo() external view returns (uint8 assetType, address assetAddress, uint8 assetDecimals);
}

contract CorrectBookValueSimulation is Test {
    address constant ORACLE = 0xD64089698f82cbCD91ba5e0422aDFa81D247eB62;
    address constant STRATEGY = 0x41A9Eb398518D2487301c61D2b33E4e966A9F1DD;
    address constant MARKET = 0x6D520a943a4Da0784917a2e71defe95248A1DaA1;

    function test_SimulateCorrectBookValue() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        IPendlePTAmortizedOracle oracle = IPendlePTAmortizedOracle(ORACLE);

        console.log("=== BEFORE CORRECTION ===");
        _logState(oracle);

        console.log("\n=== APPLYING CORRECTION ===");

        // The new book value: 50,000 SY scaled to 18 decimals
        uint128 newBookValue = 50_000 * 1e18;
        console.log("New book value to set:", uint256(newBookValue));

        // Find manager
        bytes32 managerRole = oracle.MANAGER_ROLE();
        bytes32 adminRole = oracle.DEFAULT_ADMIN_ROLE();

        // Check common addresses for manager role
        address manager = _findManager(oracle, managerRole);
        console.log("Manager found:", manager);

        // Execute correction
        vm.prank(manager);
        oracle.correctBookValue(STRATEGY, MARKET, newBookValue);
        console.log("Correction executed!");

        console.log("\n=== AFTER CORRECTION ===");
        _logState(oracle);
    }

    function _findManager(IPendlePTAmortizedOracle oracle, bytes32 managerRole) internal returns (address) {
        // Try common Superform addresses
        address[3] memory candidates = [
            0x48aB8AdF869Ba9902Ad483FB1Ca2eFDAb6eabe92,
            0x1985df46791BEBb1e3ed9Ec60417F38CECc1D349,
            0x73009CE7cFFc6C4c5363734d1b429f0b848e0490
        ];

        for (uint256 i = 0; i < candidates.length; i++) {
            if (oracle.hasRole(managerRole, candidates[i])) {
                return candidates[i];
            }
        }

        // Grant role for simulation via storage manipulation
        // AccessControl role storage: keccak256(abi.encode(account, keccak256(abi.encode(role, ROLE_SLOT))))
        // For simplicity, we'll find DEFAULT_ADMIN and grant from there
        address admin = address(this);
        bytes32 adminRole = oracle.DEFAULT_ADMIN_ROLE();

        // Grant ourselves admin role first, then manager role
        // Storage slot for _roles[role].hasRole[account] in AccessControl
        // _roles is at slot 0, hasRole mapping at slot 0 of RoleData struct
        bytes32 adminSlot = keccak256(abi.encode(admin, keccak256(abi.encode(adminRole, uint256(0)))));
        vm.store(ORACLE, adminSlot, bytes32(uint256(1)));

        bytes32 managerSlot = keccak256(abi.encode(admin, keccak256(abi.encode(managerRole, uint256(0)))));
        vm.store(ORACLE, managerSlot, bytes32(uint256(1)));

        console.log("Granted manager role to simulation address");
        return admin;
    }

    function _logState(IPendlePTAmortizedOracle oracle) internal view {
        // Book values state
        (uint128 lastBookValue, uint64 lastUpdateTime) = oracle.bookValues(STRATEGY, MARKET);
        console.log("lastUpdateBookValue (raw):", lastBookValue);
        console.log("lastUpdateTime:", lastUpdateTime);

        // Current book value
        uint256 bookValue = oracle.getBookValue(STRATEGY, MARKET);
        console.log("getBookValue:", bookValue);
        console.log("getBookValue (tokens):", bookValue / 1e18);

        // Price per share
        console.log("getPricePerShare:", oracle.getPricePerShare(MARKET));

        // PT balance
        (, address pt,) = IPMarket(MARKET).readTokens();
        uint256 ptBalance = IERC20(pt).balanceOf(STRATEGY);
        console.log("PT balance:", ptBalance);
        console.log("PT balance (tokens):", ptBalance / 1e18);

        // Market value
        uint256 marketValue = oracle.getAssetOutput(MARKET, address(0), ptBalance);
        console.log("Market value (asset output):", marketValue);

        // TVL
        uint256 tvl = oracle.getTVLByOwnerOfShares(MARKET, STRATEGY);
        console.log("TVL by owner:", tvl);
    }
}
