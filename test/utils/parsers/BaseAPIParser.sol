// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "@openzeppelin/contracts/utils/Strings.sol";

abstract contract BaseAPIParser {
    using Strings for uint256;
    using Strings for address;

    function toChecksumString(address addr) internal pure returns (string memory) {
        return Strings.toHexString(uint256(uint160(addr)), 20);
    }

    function fromHex(string memory s) public pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(
            ss.length >= 2 && ss[0] == "0" && (ss[1] == "x" || ss[1] == "X"),
            "BaseAPIParser: hex string must start with 0x"
        );

        bytes memory r = new bytes((ss.length - 2) / 2);
        for (uint256 i = 0; i < r.length; ++i) {
            r[i] = bytes1(_fromHexChar(uint8(ss[2 * i + 2])) * 16 + _fromHexChar(uint8(ss[2 * i + 3])));
        }
        return r;
    }

    function _fromHexChar(uint8 c) private pure returns (uint8) {
        if (c >= uint8(bytes1("0")) && c <= uint8(bytes1("9"))) {
            return c - uint8(bytes1("0"));
        }
        if (c >= uint8(bytes1("a")) && c <= uint8(bytes1("f"))) {
            return 10 + c - uint8(bytes1("a"));
        }
        if (c >= uint8(bytes1("A")) && c <= uint8(bytes1("F"))) {
            return 10 + c - uint8(bytes1("A"));
        }
        revert("BaseAPIParser: invalid hex char");
    }
}
