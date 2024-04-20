// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {Account, createAccount, updateERC20, updateLP, getBalances, transferTokens} from "./Account.sol";
import {isStrikeValid} from "./Pair.sol";
import {Position} from "./Position.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

/// @notice Interface for a periphery contract that settles trades
interface ICallback {
    /// @param data Extra data passed to the callback
    function callback(bytes calldata data) external;
}

/// @notice Storage data for an individual strike
/// @param token "0" if the strike holds its reserves in "token0", or "1" otherwise
/// @param amount Balance of reserves of the strike
/// @param liquidity Amount of issued liquidity
/// @param volume Cumulative amount of liquidity that has been exchanged between "token0" and "token1"
/// @param fee Amount of liquidity paid in fees currently held in the strike
struct StrikeData {
    uint8 token;
    uint256 amount;
    uint256 liquidity;
    uint256 volume;
    uint256 fee;
}

/// @notice Exchange and Liquidity Management Protocol
contract Engine is Position {
    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 ERRORS
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    error InsufficientInput();

    error InvalidStrike();

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                               DATA TYPES
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    /// @notice
    /// @param token0
    /// @param token1
    /// @param ratio
    /// @param spread
    /// @param drift
    /// @param strikeBefore
    /// @param strikeAfter
    struct Params {
        address token0;
        address token1;
        uint256 ratio;
        uint256 spread;
        int256 drift;
        StrikeData strikeBefore;
        StrikeData strikeAfter;
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                STORAGE
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    /// @notice keccak256 hash of the state of each exchange
    mapping(bytes32 strikeID => bytes32) public strikeHashes;

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 LOGIC
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    /// @notice Performs a series of trades
    /// @param params Instructions of which trades to execute
    /// @param to Recipient of the output of the trades
    /// @param data Extra data passed to the callback function of the msg.sender
    function execute(Params[] memory params, address to, bytes calldata data) external {
        unchecked {
            Account memory account = createAccount(params.length);

            for (uint256 i = 0; i < params.length; i++) {
                bytes32 strikeID = bytes32(
                    keccak256(
                        abi.encode(
                            params[i].token0, params[i].token1, params[i].ratio, params[i].spread, params[i].drift
                        )
                    )
                );

                // Update strikeHashes
                {
                    bytes32 strikeHash = strikeHashes[strikeID];
                    bytes32 _strikeHash = keccak256(abi.encode(params[i].strikeBefore));

                    // Validate strikeBefore
                    if (strikeHash == bytes32(0)) {
                        // Validate ratio + spread combination
                        uint256 ratio = params[i].ratio;
                        uint256 spread = params[i].spread;
                        if (spread > ratio || spread + ratio < ratio) revert InvalidStrike();

                        // Set strikeBefore to default value
                        params[i].strikeBefore = StrikeData({token: 0, amount: 0, liquidity: 0, volume: 0, fee: 0});
                    } else if (strikeHash != _strikeHash) {
                        revert InvalidStrike();
                    }

                    // Validate strikeAfter
                    if (!isStrikeValid(params[i].ratio, params[i].spread, params[i].drift, params[i].strikeAfter)) {
                        revert InvalidStrike();
                    }

                    // Set strikeHash
                    strikeHashes[strikeID] = keccak256(abi.encode(params[i].strikeAfter));
                }

                // Update changes in liquidity
                {
                    uint256 strikeBeforeLiquidity = params[i].strikeBefore.liquidity;
                    uint256 strikeAfterLiquidity = params[i].strikeAfter.liquidity;

                    if (strikeBeforeLiquidity > strikeAfterLiquidity) {
                        updateLP(account, strikeID, strikeBeforeLiquidity - strikeAfterLiquidity);
                    } else if (strikeBeforeLiquidity < strikeAfterLiquidity) {
                        _mint(to, strikeID, strikeAfterLiquidity - strikeBeforeLiquidity);
                    }
                }

                // Update changes in token amounts
                {
                    uint8 tokenBefore = params[i].strikeBefore.token;
                    uint8 tokenAfter = params[i].strikeAfter.token;
                    uint256 amountBefore = params[i].strikeBefore.amount;
                    uint256 amountAfter = params[i].strikeAfter.amount;
                    uint256 volumeBefore = params[i].strikeBefore.volume;
                    uint256 volumeAfter = params[i].strikeAfter.volume;

                    if (tokenBefore == tokenAfter) {
                        address token = tokenBefore == 0 ? params[i].token0 : params[i].token1;

                        if (amountBefore > amountAfter) {
                            updateERC20(account, token, amountBefore - amountAfter, false);
                        } else if (amountBefore < amountAfter) {
                            updateERC20(account, token, amountAfter - amountBefore, true);
                        }

                        if (volumeBefore != volumeAfter) revert InvalidStrike();
                    } else {
                        (address tokenIn, address tokenOut) = tokenBefore == 0
                            ? (params[i].token1, params[i].token0)
                            : (params[i].token0, params[i].token1);

                        updateERC20(account, tokenOut, amountBefore, false);
                        updateERC20(account, tokenIn, amountAfter, true);

                        if (volumeBefore + params[i].strikeBefore.liquidity != volumeAfter) revert InvalidStrike();
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
