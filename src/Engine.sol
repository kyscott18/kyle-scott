// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Account, createAccount, updateERC20, updateLP, getBalances, transferTokens} from "./Account.sol";
import {isStrikeValid} from "./Pair.sol";
import {Position} from "./Position.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

interface ICallback {
    /// @param data Extra data passed back to the callback from the caller
    function callback(bytes calldata data) external;
}

enum TokenSelector {
    Token0,
    Token1
}

struct StrikeID {
    uint256 ratio;
    uint256 spread;
}

struct StrikeData {
    TokenSelector token;
    uint256 amount;
    uint256 liquidity;
    uint256 volume;
}

function getPairID(address token0, address token1) pure returns (bytes32) {
    return keccak256(abi.encodePacked(token0, token1));
}

function getStrikeID(uint256 ratio, uint256 spread) pure returns (bytes32) {
    return keccak256(abi.encode(StrikeID({ratio: ratio, spread: spread})));
}

contract Engine is Position {
    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 ERRORS
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    error InsufficientInput();

    error InvalidStrikeHash();

    error InvalidStrike();

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                               DATA TYPES
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    struct Params {
        address token0;
        address token1;
        uint256 ratio;
        uint256 spread;
        StrikeData strikeBefore;
        StrikeData strikeAfter;
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                STORAGE
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    mapping(bytes32 pairID => mapping(bytes32 => bytes32)) public strikeHashes;

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 LOGIC
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    function execute(Params[] memory params, address to, bytes calldata data) external {
        unchecked {
            Account memory account = createAccount(params.length);

            for (uint256 i = 0; i < params.length; i++) {
                bytes32 pairID = getPairID(params[i].token0, params[i].token1);

                {
                    bytes32 strikeID = getStrikeID(params[i].ratio, params[i].spread);

                    // Verify strikeBefore
                    {
                        bytes32 strikeHash = strikeHashes[pairID][strikeID];
                        bytes32 _strikeHash = keccak256(abi.encode(params[i].strikeBefore));

                        if (strikeHash == bytes32(0)) {
                            // Validate ratio + spread combination
                            uint256 ratio = params[i].ratio;
                            uint256 spread = params[i].spread;
                            if (spread > ratio || spread + ratio < ratio) revert InvalidStrike();

                            // Set strikeBefore to default value
                            params[i].strikeBefore =
                                StrikeData({token: TokenSelector.Token0, amount: 0, liquidity: 0, volume: 0});
                        } else if (strikeHash != _strikeHash) {
                            revert InvalidStrikeHash();
                        }
                    }

                    // Verify strikeAfter
                    if (!isStrikeValid(params[i].ratio, params[i].spread, params[i].strikeAfter)) {
                        revert InvalidStrike();
                    }

                    // Save strikeAfter
                    strikeHashes[pairID][strikeID] = keccak256(abi.encode(params[i].strikeAfter));
                }

                // Update changes in liquidity
                {
                    bytes32 positionID = keccak256(abi.encode(ILRTADataID({pairID: pairID, strike: params[i].ratio})));

                    uint256 strikeBeforeLiquidity = params[i].strikeBefore.liquidity;
                    uint256 strikeAfterLiquidity = params[i].strikeAfter.liquidity;

                    if (strikeBeforeLiquidity > strikeAfterLiquidity) {
                        updateLP(account, positionID, strikeBeforeLiquidity - strikeAfterLiquidity);
                        // TODO: Withdraw earned fees.
                    } else if (strikeBeforeLiquidity < strikeAfterLiquidity) {
                        _mint(to, positionID, strikeAfterLiquidity - strikeBeforeLiquidity);
                    }
                }

                // Update changes in token amounts
                {
                    TokenSelector tokenBefore = params[i].strikeBefore.token;
                    TokenSelector tokenAfter = params[i].strikeAfter.token;
                    uint256 amountBefore = params[i].strikeBefore.amount;
                    uint256 amountAfter = params[i].strikeAfter.amount;
                    uint256 volumeBefore = params[i].strikeBefore.volume;
                    uint256 volumeAfter = params[i].strikeAfter.volume;

                    if (tokenBefore == tokenAfter) {
                        address token = tokenBefore == TokenSelector.Token0 ? params[i].token0 : params[i].token1;

                        if (amountBefore > amountAfter) {
                            updateERC20(account, token, amountBefore - amountAfter, false);
                        } else if (amountBefore < amountAfter) {
                            updateERC20(account, token, amountAfter - amountBefore, true);
                        }

                        if (volumeBefore != volumeAfter) revert InvalidStrike();
                    } else {
                        (address tokenIn, address tokenOut) = tokenBefore == TokenSelector.Token0
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

            for (uint256 i = 0; i < account.erc20DataOut.length; i++) {
                if (account.erc20DataOut[i].token == address(0)) break;

                // Note: Overflow is not handled
                if (balancesBefore[i] + account.erc20DataOut[i].amount > balancesAfter[i]) revert InsufficientInput();
            }
        }
    }
}
