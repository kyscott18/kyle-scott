// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Engine} from "src/Engine.sol";
import {mul} from "src/Math.sol";

struct Strike {
    uint256 ratio;
    uint256 liquidityH;
    uint256 liquidityL;
    Engine.TokenSelector token;
}

function getPairID(address token0, address token1) pure returns (bytes32) {
    return keccak256(abi.encodePacked(token0, token1));
}

/// @dev "amount" refers to the same token as "strike.token".
function addLiquidity(Strike memory strike, uint256 amount) pure {
    unchecked {
        uint256 _liquidityH;
        uint256 _liquidityL;

        if (strike.token == Engine.TokenSelector.Token0) {
            _liquidityL = amount;
        } else {
            (_liquidityH, _liquidityL) = mul(strike.ratio, amount);
        }

        // todo: handle overflow
        strike.liquidityH += _liquidityH;
        strike.liquidityL += _liquidityL;
    }
}

/// @dev "amount" refers to the same token as "strike.swapped".
function removeLiquidity(Strike memory strike, uint256 amount) pure {
    unchecked {
        uint256 _liquidityH;
        uint256 _liquidityL;

        if (strike.token == Engine.TokenSelector.Token0) {
            _liquidityL = amount;
        } else {
            (_liquidityH, _liquidityL) = mul(strike.ratio, amount);
        }

        // todo: handle underflow
        strike.liquidityH -= _liquidityH;
        strike.liquidityL -= _liquidityL;
    }
}

function swap(Strike memory strike) pure returns (uint256 amount0, uint256 amount1) {}
