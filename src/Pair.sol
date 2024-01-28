// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {FullMath} from "./FullMath.sol";

uint256 constant Q128 = 2 ** 128;

enum TokenSelector {
    Token0,
    Token1
}

/// @notice Strike information
/// @param liquidity Total liquidity issued for the strike
/// @param amount Balance of tokens in the strike
/// @param token Selector for which token "amount" refers to
struct StrikeData {
    uint256 liquidity;
    uint256 amount;
    TokenSelector token;
}

function isStrikeValid(uint256 strike, StrikeData memory strikeData) pure returns (bool) {
    if (strikeData.token == TokenSelector.Token0) {
        return strikeData.liquidity >= strikeData.amount;
    } else {
        return strikeData.liquidity >= FullMath.mulDivRoundingUp(strikeData.amount, strike, Q128);
    }
}

/// @notice Computes an unique identifier for a pair
function getPairID(address token0, address token1) pure returns (bytes32) {
    return keccak256(abi.encodePacked(token0, token1));
}
