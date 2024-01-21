// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Engine, ICallback} from "./Engine.sol";
import {Permit3} from "ilrta/src/Permit3.sol";

contract Router is ICallback {
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
        Permit3.SignatureTransfer signatureTransfer;
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

    function swap(
        Engine.SwapParams calldata params,
        Permit3.SignatureTransfer calldata signatureTransfer,
        bytes calldata signature
    )
        external
    {
        CallbackData memory callbackData = CallbackData(msg.sender, signatureTransfer, signature);

        engine.swap(params, abi.encode(callbackData));
    }

    function addLiquidity(
        Engine.AddLiquidityParams calldata params,
        Permit3.SignatureTransfer calldata signatureTransfer,
        bytes calldata signature
    )
        external
    {
        CallbackData memory callbackData = CallbackData(msg.sender, signatureTransfer, signature);

        engine.addLiquidity(params, abi.encode(callbackData));
    }

    function removeLiquidity(
        Engine.RemoveLiquidityParams calldata params,
        Permit3.SignatureTransfer calldata signatureTransfer,
        bytes calldata signature
    )
        external
    {
        CallbackData memory callbackData = CallbackData(msg.sender, signatureTransfer, signature);

        engine.removeLiquidity(params, abi.encode(callbackData));
    }

    function callback(bytes calldata data) external {
        if (msg.sender != address(engine)) revert InvalidCaller(msg.sender);

        CallbackData memory callbackData = abi.decode(data, (CallbackData));

        Permit3.RequestedTransferDetails memory requestedTransfer = Permit3.RequestedTransferDetails({
            to: callbackData.payer,
            transferDetails: abi.encode(callbackData.signatureTransfer.transferDetails)
        });

        permit3.transferBySignature(
            callbackData.payer, callbackData.signatureTransfer, requestedTransfer, callbackData.signature
        );
    }
}
