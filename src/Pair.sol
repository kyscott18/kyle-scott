// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {StrikeData, TokenSelector} from "./Engine.sol";
import {Q128, mulGte} from "./Math.sol";

function isStrikeValid(uint256 _ratio, int256 drift, StrikeData memory strikeData) view returns (bool) {
    unchecked {
        if (strikeData.token == TokenSelector.Token0) {
            return strikeData.liquidity <= strikeData.amount;
        } else {
            uint256 ratio;
            if (drift > 0) {
                ratio = _ratio + block.number * uint256(drift);
                if (ratio < _ratio) ratio = type(uint256).max;
            } else {
                ratio = _ratio - block.number * uint256(-drift);
                if (ratio > _ratio) ratio = 0;
            }
            return mulGte(strikeData.amount, ratio, strikeData.liquidity, Q128);
        }
    }
}
