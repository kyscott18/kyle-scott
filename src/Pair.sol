// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import {StrikeData, TokenSelector} from "./Engine.sol";
import {Q128, mulGte} from "./Math.sol";

function isStrikeValid(uint256 ratio, StrikeData memory strikeData) pure returns (bool) {
    if (strikeData.token == TokenSelector.Token0) {
        return strikeData.liquidity <= strikeData.amount;
    } else {
        return mulGte(strikeData.amount, ratio, strikeData.liquidity, Q128);
    }
}
