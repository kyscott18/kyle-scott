// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Engine} from "./Engine.sol";
import {Q128, mulgte} from "./Math.sol";

function isStrikeValid(uint256 strike, Engine.StrikeData memory strikeData) pure returns (bool) {
    if (strikeData.token == Engine.TokenSelector.Token0) {
        return strikeData.liquidity <= strikeData.amount;
    } else {
        return mulgte(strikeData.amount, strike, strikeData.liquidity, Q128);
    }
}

/// @notice Computes an unique identifier for a pair
function getPairID(address token0, address token1) pure returns (bytes32) {
    return keccak256(abi.encodePacked(token0, token1));
}
