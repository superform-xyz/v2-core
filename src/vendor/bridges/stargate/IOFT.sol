// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

struct SendParam {
    uint32 dstEid;
    bytes32 to;
    uint256 amountLD;
    uint256 minAmountLD;
    bytes extraOptions;
    bytes composeMsg;
    bytes oftCmd;
}

struct MessagingFee {
    uint256 nativeFee;
    uint256 lzTokenFee;
}

struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

struct OFTReceipt {
    uint256 amountSentLD;
    uint256 amountReceivedLD;
}

interface IOFT {
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    )
        external
        payable
        returns (MessagingReceipt memory, OFTReceipt memory);

    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    )
        external
        view
        returns (MessagingFee memory);

    function token() external view returns (address);
    function approvalRequired() external view returns (bool);
}
