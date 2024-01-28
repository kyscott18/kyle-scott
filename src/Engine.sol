// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Account, createAccount, updateERC20, updateLP, getBalances, transferTokens} from "./Account.sol";
import {isStrikeValid, getPairID, StrikeData, TokenSelector} from "./Pair.sol";
import {Position} from "./Position.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

interface ICallback {
    /// @param data Extra data passed back to the callback from the caller
    function callback(bytes calldata data) external;
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
        StrikeData strikeBefore;
        StrikeData strikeAfter;
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                STORAGE
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    mapping(bytes32 pairID => mapping(uint256 strike => bytes32)) public strikeHashes;

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 LOGIC
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    function execute(Params[] memory params, address to, bytes calldata data) external {
        unchecked {
            Account memory account = createAccount(params.length);

            for (uint256 i = 0; i < params.length; i++) {
                bytes32 pairID = getPairID(params[i].token0, params[i].token1);

                bytes32 _strikeHash = strikeHashes[pairID][params[i].ratio];
                bytes32 strikeHash = keccak256(abi.encode(params[i].strikeBefore));

                if (_strikeHash == bytes32(0)) {
                    params[i].strikeBefore = StrikeData({liquidity: 0, amount: 0, token: TokenSelector.Token0});
                } else if (_strikeHash != strikeHash) {
                    revert InvalidStrikeHash();
                }

                if (!isStrikeValid(params[i].ratio, params[i].strikeAfter)) revert InvalidStrike();

                strikeHashes[pairID][params[i].ratio] = keccak256(abi.encode(params[i].strikeAfter));

                {
                    bytes32 positionID = keccak256(abi.encode(ILRTADataID({pairID: pairID, strike: params[i].ratio})));

                    uint256 strikeBeforeLiquidity = params[i].strikeBefore.liquidity;
                    uint256 strikeAfterLiquidity = params[i].strikeAfter.liquidity;

                    if (strikeBeforeLiquidity > strikeAfterLiquidity) {
                        updateLP(account, positionID, strikeBeforeLiquidity - strikeAfterLiquidity);
                    } else if (strikeBeforeLiquidity < strikeAfterLiquidity) {
                        _mint(to, positionID, strikeAfterLiquidity - strikeBeforeLiquidity);
                    }
                }

                {
                    TokenSelector tokenBefore = params[i].strikeBefore.token;
                    TokenSelector tokenAfter = params[i].strikeAfter.token;
                    uint256 amountBefore = params[i].strikeBefore.amount;
                    uint256 amountAfter = params[i].strikeAfter.amount;

                    if (tokenBefore == tokenAfter) {
                        if (amountBefore > amountAfter) {
                            updateERC20(
                                account,
                                tokenBefore == TokenSelector.Token0 ? params[i].token0 : params[i].token1,
                                amountBefore - amountAfter,
                                false
                            );
                        } else if (amountBefore < amountAfter) {
                            updateERC20(
                                account,
                                tokenBefore == TokenSelector.Token0 ? params[i].token0 : params[i].token1,
                                amountAfter - amountBefore,
                                true
                            );
                        }
                    } else {
                        updateERC20(
                            account,
                            tokenBefore == TokenSelector.Token0 ? params[i].token0 : params[i].token1,
                            amountBefore,
                            false
                        );
                        updateERC20(
                            account,
                            tokenAfter == TokenSelector.Token0 ? params[i].token0 : params[i].token1,
                            amountAfter,
                            true
                        );
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
