// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {
    ILayerZeroEndpointV2,
    MessagingParams,
    MessagingFee,
    MessagingReceipt,
    Origin
} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

/**
 * @title MockLZEndpoint
 * @notice Minimal mock of ILayerZeroEndpointV2 for unit testing Token.sol.
 * @dev Only implements functions called by Token.sol: quote(), send(), setDelegate(), sendCompose(), lzToken().
 */
contract MockLZEndpoint {
    // Track delegate calls for assertions
    address public lastDelegate;
    uint32 public lastSendDstEid;
    bytes public lastSendMessage;
    uint256 public sendCallCount;

    // Configurable quote fee for testing
    uint256 public mockNativeFee;
    uint256 public mockLzTokenFee;

    function setMockFees(uint256 _nativeFee, uint256 _lzTokenFee) external {
        mockNativeFee = _nativeFee;
        mockLzTokenFee = _lzTokenFee;
    }

    function setDelegate(address _delegate) external {
        lastDelegate = _delegate;
    }

    function quote(MessagingParams calldata, address)
        external
        view
        returns (MessagingFee memory)
    {
        return MessagingFee(mockNativeFee, mockLzTokenFee);
    }

    function send(MessagingParams calldata _params, address)
        external
        payable
        returns (MessagingReceipt memory receipt)
    {
        lastSendDstEid = _params.dstEid;
        lastSendMessage = _params.message;
        sendCallCount++;

        receipt = MessagingReceipt(
            keccak256(abi.encodePacked(sendCallCount, block.timestamp)),
            uint64(sendCallCount),
            MessagingFee(msg.value, 0)
        );
    }

    function sendCompose(address, bytes32, uint16, bytes calldata) external { }

    function lzToken() external pure returns (address) {
        return address(0);
    }

    // Allow receiving ETH
    receive() external payable { }
}
