// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Engine, ICallback, Trade} from "./Engine.sol";
import {Permit3} from "ilrta/src/Permit3.sol";

contract RouterPermit3 is ICallback {
    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 ERRORS
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    /// @notice Thrown when callback is called by an invalid address
    error InvalidCaller(address caller);

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                               DATA TYPES
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    struct CallbackData {
        address payer;
        Permit3.SignatureTransferBatch signatureTransfer;
        bytes signature;
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                STORAGE
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    Engine public immutable engine;

    Permit3 public immutable permit3;

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                              CONSTRUCTOR
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    constructor(address payable _engine, address _permit3) {
        engine = Engine(_engine);
        permit3 = Permit3(_permit3);
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 LOGIC
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    function route(
        Trade[] calldata trades,
        address to,
        Permit3.SignatureTransferBatch calldata signatureTransfer,
        bytes calldata signature
    )
        external
    {
        CallbackData memory callbackData = CallbackData(msg.sender, signatureTransfer, signature);

        engine.execute(trades, to, abi.encode(callbackData));
    }

    function callback(bytes calldata data) external {
        unchecked {
            if (msg.sender != address(engine)) revert InvalidCaller(msg.sender);

            CallbackData memory callbackData = abi.decode(data, (CallbackData));

            Permit3.RequestedTransferDetails[] memory requestedTransfer =
                new Permit3.RequestedTransferDetails[](callbackData.signatureTransfer.transferDetails.length);

            for (uint256 i = 0; i < requestedTransfer.length; i++) {
                requestedTransfer[i] = Permit3.RequestedTransferDetails({
                    to: callbackData.payer,
                    transferDetails: abi.encode(callbackData.signatureTransfer.transferDetails[i])
                });
            }

            permit3.transferBySignature(
                callbackData.payer, callbackData.signatureTransfer, requestedTransfer, callbackData.signature
            );
        }
    }
}
