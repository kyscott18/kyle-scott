// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {StrikeData, TokenSelector} from "./Engine.sol";
import {Q128, mulEq} from "./Math.sol";

function isStrikeValid(
    uint256 _ratio,
    uint256 spread,
    int256 drift,
    StrikeData memory strikeData
)
    view
    returns (bool)
{
    unchecked {
        if (strikeData.token == TokenSelector.Token0) {
            return mulEq(strikeData.fee, Q128, strikeData.volume, spread) && strikeData.amount == strikeData.liquidity;
        } else {
            uint256 ratio;
            if (drift > 0) {
                ratio = (_ratio - spread) + block.number * uint256(drift);
                if (ratio < _ratio - spread) ratio = type(uint256).max;
            } else if (drift < 0) {
                ratio = (_ratio - spread) - block.number * uint256(-drift);
                if (ratio > _ratio - spread) ratio = 0;
            } else {
                ratio = _ratio - spread;
            }

            return mulEq(strikeData.fee, strikeData.volume, Q128, spread)
                && mulEq(strikeData.amount, ratio, strikeData.liquidity, Q128);
        }
    }
}
