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
/// @param balance
struct ExchangeState {
    uint8 token;
    uint256 amount;
    uint256 liquidity;
    uint256 balance;
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

        // Validate fee and balance changes
        bool isSwap = trade.stateBefore.token != trade.stateAfter.token;
        if (isSwap) {
            if (mulGte(trade.fee, Q128, trade.stateAfter.liquidity, trade.exchange.spread) == false) return false;
            if (trade.stateBefore.liquidity + trade.fee != trade.stateAfter.liquidity) return false;
            if (trade.stateBefore.balance != trade.stateAfter.balance) return false;
        } else {
            if (trade.stateBefore.liquidity > trade.stateAfter.liquidity) {
                if (trade.stateBefore.balance < trade.stateAfter.balance) return false;
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

    /// @notice Performs a series of trades, and settles the aggregate by calling into a callback
    /// @param trades Instructions of which trades to execute
    /// @param to Recipient of the output of the trades
    /// @param data Extra data passed to the callback function of the msg.sender
    function execute(Trade[] memory trades, address to, bytes calldata data) external {
        unchecked {
            Account memory account = createAccount(trades.length);

            for (uint256 i = 0; i < trades.length; i++) {
                bytes32 exchangeID = bytes32(keccak256(abi.encode(trades[i].exchange)));

                // Update stateHashes
                {
                    bytes32 stateHash = stateHashes[exchangeID];
                    bytes32 _stateHash = keccak256(abi.encode(trades[i].stateBefore));

                    // Validate stateBefore
                    if (stateHash == bytes32(0)) {
                        // Validate ratio + spread combination
                        uint256 ratio = trades[i].exchange.ratio;
                        uint256 spread = trades[i].exchange.spread;
                        if (spread > ratio || spread + ratio < ratio) revert();

                        // Set stateBefore to default value
                        trades[i].stateBefore = ExchangeState({token: 0, amount: 0, liquidity: 0, balance: 0});
                    } else if (stateHash != _stateHash) {
                        revert();
                    }

                    // Validate trade
                    if (isTradeValid(trades[i]) == false) {
                        revert();
                    }

                    // Set stateHash
                    stateHashes[exchangeID] = keccak256(abi.encode(trades[i].stateAfter));
                }

                // Update changes in liquidity
                {
                    uint256 stateBeforeBalance = trades[i].stateBefore.balance;
                    uint256 stateAfterBalance = trades[i].stateAfter.balance;

                    if (stateBeforeBalance > stateAfterBalance) {
                        updateLP(account, exchangeID, stateBeforeBalance - stateAfterBalance);
                    } else if (stateBeforeBalance < stateAfterBalance) {
                        _mint(to, exchangeID, stateAfterBalance - stateAfterBalance);
                    }
                }

                // Update changes in token amounts
                {
                    uint8 tokenBefore = trades[i].stateBefore.token;
                    uint8 tokenAfter = trades[i].stateAfter.token;
                    uint256 amountBefore = trades[i].stateBefore.amount;
                    uint256 amountAfter = trades[i].stateAfter.amount;

                    if (tokenBefore == tokenAfter) {
                        address token = tokenBefore == 0 ? trades[i].exchange.token0 : trades[i].exchange.token1;

                        if (amountBefore > amountAfter) {
                            updateERC20(account, token, amountBefore - amountAfter, false);
                        } else if (amountBefore < amountAfter) {
                            updateERC20(account, token, amountAfter - amountBefore, true);
                        }
                    } else {
                        (address tokenIn, address tokenOut) = tokenBefore == 0
                            ? (trades[i].exchange.token1, trades[i].exchange.token0)
                            : (trades[i].exchange.token0, trades[i].exchange.token1);

                        updateERC20(account, tokenOut, amountBefore, false);
                        updateERC20(account, tokenIn, amountAfter, true);
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

                if (balancesBefore[i] + account.erc20DataIn[i].amount != balancesAfter[i]) revert();
            }

            // Receive liquidity
            for (uint256 i = 0; i < account.lpCount; i++) {
                if (account.lpData[i].amount != _dataOf[address(this)][account.lpData[i].id].balance) {
                    revert();
                }
                _burn(address(this), account.lpData[i].id, account.lpData[i].amount);
            }
        }
    }
}
