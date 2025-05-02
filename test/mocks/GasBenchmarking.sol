// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;



contract ValidatorSimulation {

    mapping(uint256 identifier => bytes sigData) public signaturesRegistry;

    function validate(bytes calldata userOpCalldata) external {
        // assume signature is the last 32 bytes
        bytes memory signature = userOpCalldata[userOpCalldata.length - 32:];

        signaturesRegistry[0] = signature;
    }
}


contract GasBenchmarker {
    struct Info {
        uint256 hookIndex;
        uint256 startBytes;
        uint256 endBytes;
    }

    address public validator;
    event SomeStuff(bytes s);

    constructor(address _validator) {
        validator = _validator;
    }


    function handleUserOpStore(bytes calldata userOpCalldata) external {
        ValidatorSimulation(validator).validate(userOpCalldata);    

        bytes memory sig = ValidatorSimulation(validator).signaturesRegistry(0);
        emit SomeStuff(sig);
    }

    function handleUserOpReplace(bytes calldata userOpCalldata) external { 
        /**
        [... other calldata ...]
        [Info array]
        [Signature (65 bytes)]
        [InfoLength (32 bytes)]
        [SignatureLength (1 byte)]
         */
        (Info[] memory infoArray, bytes memory signature) = parseCalldata(userOpCalldata);

        uint256 readPtr = 0; // pointer in userOpCalldata
        uint256 sigPtr = 0;  // pointer in signature
        uint256 writePtr = 0;

        bytes memory result = new bytes(userOpCalldata.length);

        for (uint256 i = 0; i < infoArray.length; i++) {
            Info memory info = infoArray[i];

            // Copy unchanged segment up to startBytes
            uint256 unchangedLen = info.startBytes - readPtr;
            for (uint256 j = 0; j < unchangedLen; j++) {
                result[writePtr++] = userOpCalldata[readPtr++];
            }

            // Replace bytes from signature
            uint256 replaceLen = info.endBytes - info.startBytes;
            for (uint256 j = 0; j < replaceLen; j++) {
                result[writePtr++] = signature[sigPtr++];
                readPtr++; // skip replaced byte
            }
        }

        // Copy remaining bytes after last replacement
        while (readPtr < userOpCalldata.length) {
            result[writePtr++] = userOpCalldata[readPtr++];
        }
        emit SomeStuff(result);
    }

    function parseCalldata(bytes calldata data) internal pure returns (
        Info[] memory infoArray,
        bytes memory signature
    ) {
        uint256 totalLength = data.length;

        // Signature length is last byte
        uint8 signatureLength = uint8(data[totalLength - 1]);

        // Info length is 32 bytes before that
        uint256 infoLengthOffset = totalLength - 1 - 32;
        uint256 infoLength = bytesToUint256(data[infoLengthOffset : infoLengthOffset + 32]);

        // Extract signature
        uint256 signatureOffset = infoLengthOffset - signatureLength;
        signature = data[signatureOffset : signatureOffset + signatureLength];

        // Extract Info array
        infoArray = decodeInfoArray(data, signatureOffset, infoLength);
    }

    function decodeInfoArray(bytes calldata data, uint256 infoSectionEnd, uint256 infoLength) internal pure returns (Info[] memory infoArray) {
        uint256 infoItemSize = 96;
        infoArray = new Info[](infoLength);

        for (uint256 i = 0; i < infoLength; i++) {
            uint256 base = infoSectionEnd - infoItemSize * (infoLength - i);

            infoArray[i] = Info({
                hookIndex: bytesToUint256(data[base : base + 32]),
                startBytes: bytesToUint256(data[base + 32 : base + 64]),
                endBytes: bytesToUint256(data[base + 64 : base + 96])
            });
        }
    }

    function bytesToUint256(bytes calldata b) internal pure returns (uint256 result) {
        require(b.length == 32, "Invalid uint256 slice length");
        assembly {
            result := calldataload(b.offset)
        }
    }
}