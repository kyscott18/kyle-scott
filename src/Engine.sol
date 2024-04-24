// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Account, createAccount, updateERC20, updateLP, getBalances, transferTokens} from "./Account.sol";
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
/// @param token0 First token in the exchange
/// @param token1 Second token in the exchange
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
/// @param volume Cumulative amount of liquidity that has been exchanged between "token0" and "token1"
/// @param fee Amount of liquidity paid in fees currently held in the exchange
struct ExchangeState {
    uint8 token;
    uint256 amount;
    uint256 liquidity;
    uint256 volume;
    uint256 fee;
}

/// @notice Returns true if the exchange + state satisfy the protocol invariant
/// @dev l <= x + p * y
function isExchangeStateValid(Exchange memory exchange, ExchangeState memory state) view returns (bool) {
    unchecked {
        if (!mulGte(state.fee, Q128, state.volume, exchange.spread)) return false;

        if (state.token == 0) {
            return state.amount == state.liquidity + state.fee;
        } else {
            uint256 ratio;
            if (exchange.drift > 0) {
                ratio = (exchange.ratio - exchange.spread) + block.number * uint256(exchange.drift);
                if (ratio < exchange.ratio - exchange.spread) ratio = type(uint256).max;
            } else if (exchange.drift < 0) {
                ratio = (exchange.ratio - exchange.spread) - block.number * uint256(-exchange.drift);
                if (ratio > exchange.ratio - exchange.spread) ratio = 0;
            } else {
                ratio = exchange.ratio - exchange.spread;
            }

            return mulGte(state.amount, ratio, state.liquidity + state.fee, Q128);
        }
    }
}

/// @notice ...
contract Engine is Position {
    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 ERRORS
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    error InsufficientInput();

    error InvalidExchange();

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                               DATA TYPES
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    /// @notice
    /// @param Exchange
    /// @param stateBefore
    /// @param stateAfter
    struct Trade {
        Exchange exchange;
        ExchangeState stateBefore;
        ExchangeState stateAfter;
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                STORAGE
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    /// @notice keccak256 hash of the state of each exchange
    mapping(bytes32 exchangeID => bytes32) public exchangeHashes;

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 LOGIC
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    /// @notice Performs a series of trades, and settles the aggregate by calling into a callback
    /// @param trades Instructions of which trades to execute
    /// @param to Recipient of the output of the trades
    /// @param data Extra data passed to the callback function of the msg.sender
    function execute(Trade[] memory trades, address to, bytes calldata data) external {
        unchecked {
            Account memory account = createAccount(trades.length);

            for (uint256 i = 0; i < trades.length; i++) {
                bytes32 exchangeID = bytes32(keccak256(abi.encode(trades[i].exchange)));

                // Update exchangeHashes
                {
                    bytes32 exchangeHash = exchangeHashes[exchangeID];
                    bytes32 _exchangeHash = keccak256(abi.encode(trades[i].stateBefore));

                    // Validate exchangeBefore
                    if (exchangeHash == bytes32(0)) {
                        // Validate ratio + spread combination
                        uint256 ratio = trades[i].exchange.ratio;
                        uint256 spread = trades[i].exchange.spread;
                        if (spread > ratio || spread + ratio < ratio) revert InvalidExchange();

                        // Set stateBefore to default value
                        trades[i].stateBefore = ExchangeState({token: 0, amount: 0, liquidity: 0, volume: 0, fee: 0});
                    } else if (exchangeHash != _exchangeHash) {
                        revert InvalidExchange();
                    }

                    // Validate stateAfter
                    if (!isExchangeStateValid(trades[i].exchange, trades[i].stateAfter)) {
                        revert InvalidExchange();
                    }

                    // Set exchangeHash
                    exchangeHashes[exchangeID] = keccak256(abi.encode(trades[i].stateAfter));
                }

                // Update changes in liquidity
                {
                    uint256 stateBeforeLiquidity = trades[i].stateBefore.liquidity;
                    uint256 stateAfterLiquidity = trades[i].stateAfter.liquidity;

                    if (stateBeforeLiquidity > stateAfterLiquidity) {
                        updateLP(account, exchangeID, stateBeforeLiquidity - stateAfterLiquidity);
                    } else if (stateBeforeLiquidity < stateAfterLiquidity) {
                        _mint(to, exchangeID, stateAfterLiquidity - stateBeforeLiquidity);
                    }
                }

                // Update changes in token amounts
                {
                    uint8 tokenBefore = trades[i].stateBefore.token;
                    uint8 tokenAfter = trades[i].stateAfter.token;
                    uint256 amountBefore = trades[i].stateBefore.amount;
                    uint256 amountAfter = trades[i].stateAfter.amount;
                    uint256 volumeBefore = trades[i].stateBefore.volume;
                    uint256 volumeAfter = trades[i].stateAfter.volume;

                    if (tokenBefore == tokenAfter) {
                        address token = tokenBefore == 0 ? trades[i].exchange.token0 : trades[i].exchange.token1;

                        if (amountBefore > amountAfter) {
                            updateERC20(account, token, amountBefore - amountAfter, false);
                        } else if (amountBefore < amountAfter) {
                            updateERC20(account, token, amountAfter - amountBefore, true);
                        }

                        if (volumeBefore != volumeAfter) revert InvalidExchange();
                    } else {
                        (address tokenIn, address tokenOut) = tokenBefore == 0
                            ? (trades[i].exchange.token1, trades[i].exchange.token0)
                            : (trades[i].exchange.token0, trades[i].exchange.token1);

                        updateERC20(account, tokenOut, amountBefore, false);
                        updateERC20(account, tokenIn, amountAfter, true);

                        if (volumeBefore + trades[i].stateBefore.liquidity != volumeAfter) revert InvalidExchange();
                    }
                }
            }

            transferTokens(account, to);

            uint256[] memory balancesBefore = getBalances(account, address(this));
            ICallback(msg.sender).callback(data);
            uint256[] memory balancesAfter = getBalances(account, address(this));

            // Receive tokens
            for (uint256 i = 0; i < account.erc20DataIn.length; i++) {
                if (account.erc20DataIn[i].token == address(0)) break;

                if (balancesBefore[i] + account.erc20DataIn[i].amount != balancesAfter[i]) revert InsufficientInput();
            }

            // Receive liquidity
            for (uint256 i = 0; i < account.lpCount; i++) {
                if (account.lpData[i].amount != _dataOf[address(this)][account.lpData[i].id].balance) {
                    revert InsufficientInput();
                }
                _burn(address(this), account.lpData[i].id, account.lpData[i].amount);
            }
        }
    }
}
