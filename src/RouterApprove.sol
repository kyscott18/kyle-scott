// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Engine, ICallback} from "./Engine.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

contract RouterApprove is ICallback {
    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 ERRORS
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    /// @notice Thrown when callback is called by an invalid address
    error InvalidCaller(address caller);

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                               DATA TYPES
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    struct TokenAmount {
        address token;
        uint256 amount;
    }

    struct CallbackData {
        address payer;
        TokenAmount[] tokenAmounts;
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                STORAGE
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    Engine public immutable engine;

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                              CONSTRUCTOR
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    constructor(address payable _engine) {
        engine = Engine(_engine);
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 LOGIC
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    function route(Engine.Params[] calldata params, address to, TokenAmount[] memory tokenAmounts) external {
        CallbackData memory callbackData = CallbackData({payer: msg.sender, tokenAmounts: tokenAmounts});

        engine.execute(params, to, abi.encode(callbackData));
    }

    function callback(bytes calldata data) external {
        unchecked {
            if (msg.sender != address(engine)) revert InvalidCaller(msg.sender);

            CallbackData memory callbackData = abi.decode(data, (CallbackData));

            for (uint256 i = 0; i < callbackData.tokenAmounts.length; i++) {
                SafeTransferLib.safeTransferFrom(
                    ERC20(callbackData.tokenAmounts[i].token),
                    callbackData.payer,
                    msg.sender,
                    callbackData.tokenAmounts[i].amount
                );
            }
        }
    }
}
