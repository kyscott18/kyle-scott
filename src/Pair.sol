// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {StrikeData, TokenSelector} from "./Engine.sol";
import {Q128, mulGte, mulDiv} from "./Math.sol";

function isStrikeValid(uint256 ratio, uint256 spread, StrikeData memory strikeData) pure returns (bool) {
    unchecked {
        uint256 _l;

        if (strikeData.token == TokenSelector.Token0) {
            _l = strikeData.amount;
        } else {
            _l = mulDiv(strikeData.amount, ratio, Q128);
        }

        if (strikeData.liquidity > _l) return false;

        return mulGte(_l - strikeData.liquidity, ratio, spread, strikeData.volume);
    }
}
