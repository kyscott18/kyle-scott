// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {uint512, mul, div, divRoundUp, Q128} from "src/Math.sol";

enum TokenSelector {
    Token0,
    Token1
}

/// @notice Strike information
/// @param ratio Q128.128 number for the exchange rate (0/1) of the pair
/// @param amount Balance of tokens in the strike
/// @param token Selector for which token "amount" refers to
struct Strike {
    uint256 ratio;
    uint256 amount;
    TokenSelector token;
}

/// @notice Computes an unique identifier for a pair
/// @dev token0 must sort before token1
function getPairID(address token0, address token1) pure returns (bytes32) {
    return keccak256(abi.encodePacked(token0, token1));
}

function swap(Strike memory strike) pure returns (uint256, uint256) {
    if (strike.token == TokenSelector.Token0) {
        uint256 amount0 = strike.amount;
        uint256 amount1 = divRoundUp(mul(amount0, Q128), strike.ratio);

        strike.amount = amount1;
        strike.token = TokenSelector.Token1;
        return (amount0, amount1);
    } else {
        uint256 amount1 = strike.amount;
        uint256 amount0 = divRoundUp(mul(amount1, strike.ratio), Q128);

        strike.amount = amount0;
        strike.token = TokenSelector.Token0;
        return (amount0, amount1);
    }
}

/// @dev "amount" refers to the same token as "strike.token".
function addLiquidity(Strike memory strike, uint256 amount) pure returns (uint256, uint256, uint512 memory) {
    unchecked {
        strike.amount += amount;
        uint512 memory liquidity;

        if (strike.token == TokenSelector.Token0) {
            liquidity = mul(amount, Q128);
            return (amount, uint256(0), liquidity);
        } else {
            liquidity = mul(amount, strike.ratio);
            return (uint256(0), amount, liquidity);
        }
    }
}

/// @dev "amount" refers to the same token as "strike.token".
function removeLiquidity(Strike memory strike, uint256 amount) pure returns (uint256, uint256, uint512 memory) {
    unchecked {
        strike.amount -= amount;
        uint512 memory liquidity;

        if (strike.token == TokenSelector.Token0) {
            liquidity = mul(amount, Q128);
            return (amount, uint256(0), liquidity);
        } else {
            liquidity = mul(amount, strike.ratio);
            return (uint256(0), amount, liquidity);
        }
    }
}
