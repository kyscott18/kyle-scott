// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Engine, ICallback, Trade} from "./Engine.sol";
import {Position} from "./Position.sol";
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

    struct LiquidityAmount {
        bytes32 id;
        uint256 amount;
    }

    struct CallbackData {
        address payer;
        TokenAmount[] tokenAmounts;
        LiquidityAmount[] liquidityAmounts;
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

    function route(
        Trade[] calldata trades,
        address to,
        TokenAmount[] memory tokenAmounts,
        LiquidityAmount[] memory liquidityAmounts
    )
        external
    {
        CallbackData memory callbackData =
            CallbackData({payer: msg.sender, tokenAmounts: tokenAmounts, liquidityAmounts: liquidityAmounts});

        engine.execute(trades, to, abi.encode(callbackData));
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

            for (uint256 i = 0; i < callbackData.liquidityAmounts.length; i++) {
                Engine(engine).transferFrom_XXXXX(
                    callbackData.payer,
                    msg.sender,
                    Position.ILRTATransferDetails(
                        callbackData.liquidityAmounts[i].id, callbackData.liquidityAmounts[i].amount
                    )
                );
            }
        }
    }
}
