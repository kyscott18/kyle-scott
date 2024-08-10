// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Q128, mulGte} from "./Math.sol";
import {Position} from "./Position.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

/// @notice Interface for a periphery contract that settles trades
interface ICallback {
    /// @param data Extra data passed to the callback
    function callback(bytes calldata data) external;
}

/// @notice Identifying information for an exchange
/// @param token0 Base token in the exchange
/// @param token1 Quote token in the exchange
/// @param ratio Initial exchange rate as a Q128.128 value
/// @param spread Difference between ratio and ...
/// @param drift Change in ratio per block
struct Exchange {
    address token0;
    address token1;
    uint256 ratio;
    uint256 spread;
    int256 drift;
}

/// @notice State of an individual exchange
/// @param token "0" if the exchange holds its reserves in "token0", or "1" otherwise
/// @param amount Balance of reserves
/// @param liquidity Balance of issued liquidity
/// @param balance Total supply of exchange shares
/// @param taker Account that is currently reserving the exchange, address(0) if none
/// @param expiry Block when reserve expires
struct ExchangeState {
    uint8 token;
    uint256 amount;
    uint256 liquidity;
    uint256 balance;
    uint256 expiry;
    address taker;
}

/// @notice
/// @param exchange
/// @param stateBefore
/// @param stateAfter
/// @param fee
struct Trade {
    Exchange exchange;
    ExchangeState stateBefore;
    ExchangeState stateAfter;
    uint256 fee;
}

/// @notice Returns true if the trade satisfies the protocol invariant
function isTradeValid(Trade memory trade) view returns (bool) {
    unchecked {
        // Validate reservation is respected
        if (block.number < trade.stateBefore.expiry && trade.stateBefore.taker != msg.sender) return false;

        // Validate stateAfter invariant: l <= x + p * y
        if (trade.stateAfter.token == 0) {
            if (trade.stateAfter.amount != trade.stateAfter.liquidity) return false;
        } else {
            uint256 ratio = trade.exchange.ratio;
            if (trade.exchange.drift > 0) {
                ratio += block.number * uint256(trade.exchange.drift);
                if (ratio < trade.exchange.ratio) ratio = type(uint256).max;
            } else if (trade.exchange.drift < 0) {
                ratio -= block.number * uint256(-trade.exchange.drift);
                if (ratio > trade.exchange.ratio) ratio = 0;
            }

            if (mulGte(trade.stateAfter.amount, ratio, trade.stateAfter.liquidity, Q128) == false) return false;
        }

        // Validate delta between states

        bool isReserve = trade.stateBefore.taker != trade.stateAfter.taker;
        bool isSwap = trade.stateBefore.token != trade.stateAfter.token;

        if (isReserve) {
            if (trade.stateBefore.taker == address(0)) {
                if (isSwap) return false;
                if (mulGte(trade.fee, Q128, trade.stateBefore.liquidity, trade.exchange.spread) == false) return false;
                if (trade.stateBefore.liquidity + trade.fee != trade.stateAfter.liquidity) return false;
                if (trade.stateBefore.balance != trade.stateAfter.balance) return false;
                if (trade.stateAfter.expiry != block.number + 1) return false;
            } else {
                if (trade.stateBefore.liquidity != trade.stateAfter.liquidity) return false;
                if (trade.stateBefore.balance != trade.stateAfter.balance) return false;
                if (trade.stateBefore.expiry != trade.stateAfter.expiry) return false;
                if (trade.stateAfter.taker != address(0)) return false;
            }
        } else if (isSwap) {
            if (mulGte(trade.fee, Q128, trade.stateBefore.liquidity, trade.exchange.spread) == false) return false;
            if (trade.stateBefore.liquidity + trade.fee != trade.stateAfter.liquidity) return false;
            if (trade.stateBefore.balance != trade.stateAfter.balance) return false;
        } else {
            if (trade.stateBefore.liquidity > trade.stateAfter.liquidity) {
                if (trade.stateBefore.balance < trade.stateAfter.balance) return false;
                if (trade.stateAfter.liquidity == 0 && trade.stateAfter.balance != trade.stateAfter.liquidity) {
                    return false;
                }
                if (
                    mulGte(
                        trade.stateBefore.balance - trade.stateAfter.balance,
                        trade.stateBefore.liquidity,
                        trade.stateBefore.liquidity - trade.stateAfter.liquidity,
                        trade.stateBefore.balance
                    ) == false
                ) return false;
            } else if (trade.stateBefore.liquidity < trade.stateAfter.liquidity) {
                if (trade.stateBefore.balance > trade.stateAfter.balance) return false;
                if (trade.stateBefore.liquidity == 0 && trade.stateAfter.balance != trade.stateAfter.liquidity) {
                    return false;
                }
                if (
                    mulGte(
                        trade.stateAfter.liquidity - trade.stateBefore.liquidity,
                        trade.stateBefore.balance,
                        trade.stateAfter.balance - trade.stateBefore.balance,
                        trade.stateBefore.liquidity
                    ) == false
                ) return false;
            } else {
                if (trade.stateBefore.balance != trade.stateAfter.balance) return false;
            }
        }

        return true;
    }
}

/// @notice ...
contract Engine is Position {
    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                STORAGE
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    /// @notice keccak256 hash of the state of each exchange
    mapping(bytes32 exchangeID => bytes32) public stateHashes;

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 LOGIC
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    /// @notice
    /// @param trade Instructions of the trade to execute
    /// @param to Recipient of the output of the trade
    /// @param data Extra data passed to the callback function of the msg.sender
    function execute(Trade memory trade, address to, bytes calldata data) external {
        unchecked {
            bytes32 exchangeID = bytes32(keccak256(abi.encode(trade.exchange)));

            // Update stateHashes
            {
                bytes32 stateHash = stateHashes[exchangeID];
                bytes32 _stateHash = keccak256(abi.encode(trade.stateBefore));

                // Validate stateBefore
                if (stateHash == bytes32(0)) {
                    // Validate ratio + spread combination
                    uint256 ratio = trade.exchange.ratio;
                    uint256 spread = trade.exchange.spread;
                    if (spread > ratio || spread + ratio < ratio) revert();

                    // Set stateBefore to default value
                    trade.stateBefore = ExchangeState({
                        token: trade.stateAfter.token,
                        amount: 0,
                        liquidity: 0,
                        balance: 0,
                        expiry: 0,
                        taker: address(0)
                    });
                } else if (stateHash != _stateHash) {
                    revert();
                }

                // Validate trade
                if (isTradeValid(trade) == false) {
                    revert();
                }

                // Set stateHash
                stateHashes[exchangeID] = keccak256(abi.encode(trade.stateAfter));
            }

            // 0: no-op, 1: transfer out, 2: transfer in
            uint8 sign0;
            uint8 sign1;
            uint256 amount0;
            uint256 amount1;
            uint256 balance;

            // Update changes in liquidity
            {
                uint256 stateBeforeBalance = trade.stateBefore.balance;
                uint256 stateAfterBalance = trade.stateAfter.balance;

                if (stateBeforeBalance > stateAfterBalance) {
                    balance = stateBeforeBalance - stateAfterBalance;
                } else if (stateBeforeBalance < stateAfterBalance) {
                    _mint(to, exchangeID, stateAfterBalance - stateBeforeBalance);
                }
            }

            // Update changes in token amounts
            {
                uint8 tokenBefore = trade.stateBefore.token;
                uint8 tokenAfter = trade.stateAfter.token;
                uint256 amountBefore = trade.stateBefore.amount;
                uint256 amountAfter = trade.stateAfter.amount;

                if (tokenBefore == tokenAfter) {
                    if (tokenBefore == 0) {
                        if (amountBefore > amountAfter) {
                            amount0 = amountBefore - amountAfter;
                            sign0 = 1;
                        } else {
                            amount0 = amountAfter - amountBefore;
                            sign0 = 2;
                        }
                    } else {
                        if (amountBefore > amountAfter) {
                            amount1 = amountBefore - amountAfter;
                            sign1 = 1;
                        } else {
                            amount1 = amountAfter - amountBefore;
                            sign1 = 2;
                        }
                    }
                } else {
                    if (tokenBefore == 0) {
                        amount0 = amountBefore;
                        amount1 = amountAfter;
                        sign0 = 1;
                        sign1 = 2;
                    } else {
                        amount0 = amountAfter;
                        amount1 = amountBefore;
                        sign0 = 2;
                        sign1 = 1;
                    }
                }
            }

            if (sign0 == 1) {
                SafeTransferLib.safeTransfer(ERC20(trade.exchange.token0), to, amount0);
            }
            if (sign1 == 1) {
                SafeTransferLib.safeTransfer(ERC20(trade.exchange.token1), to, amount1);
            }

            uint256 reserve0Before = sign0 == 2 ? ERC20(trade.exchange.token0).balanceOf(address(this)) : 0;
            uint256 reserve1Before = sign1 == 2 ? ERC20(trade.exchange.token1).balanceOf(address(this)) : 0;
            ICallback(msg.sender).callback(data);
            uint256 reserve0After = sign0 == 2 ? ERC20(trade.exchange.token0).balanceOf(address(this)) : 0;
            uint256 reserve1After = sign1 == 2 ? ERC20(trade.exchange.token1).balanceOf(address(this)) : 0;

            // Receive tokens
            if (sign0 == 2 && reserve0Before + amount0 != reserve0After) revert();
            if (sign1 == 2 && reserve1Before + amount1 != reserve1After) revert();

            // Receive liquidity
            if (balance != 0) {
                _burn(address(this), exchangeID, balance);
            }
        }
    }
}
