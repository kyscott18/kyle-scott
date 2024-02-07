// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Engine} from "./Engine.sol";
import {Q128, mulGte, mulDiv} from "./Math.sol";

function isStrikeValid(uint256 ratio, uint256 spread, Engine.StrikeData memory strikeData) pure returns (bool) {
    unchecked {
        uint256 _l;

        if (strikeData.token == Engine.TokenSelector.Token0) {
            _l = strikeData.amount;
        } else {
            _l = mulDiv(strikeData.amount, ratio, Q128);
        }

        if (strikeData.liquidity > _l) return false;

        return mulGte(_l - strikeData.liquidity, ratio, spread, strikeData.liquiditySwapGrowth);
    }
}

/// @notice Computes an unique identifier for a pair
function getPairID(address token0, address token1) pure returns (bytes32) {
    return keccak256(abi.encodePacked(token0, token1));
}
