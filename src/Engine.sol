// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {
    Strike,
    getPairID,
    swap as pairSwap,
    addLiquidity as pairAddLiquidity,
    removeLiquidity as pairRemoveLiquidity
} from "src/Pair.sol";

interface ICallback {
    /// @param data Extra data passed back to the callback from the caller
    function callback(bytes calldata data) external;
}

contract Engine {
    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 ERRORS
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    error InvalidStrikeHash();

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                               DATA TYPES
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    struct SwapParams {
        address token0;
        address token1;
        Strike[] strikes;
    }

    struct AddLiquidityParams {
        address token0;
        address token1;
        Strike strike;
        uint256 amount;
    }

    struct RemoveLiquidityParams {
        address token0;
        address token1;
        Strike strike;
        uint256 amount;
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                STORAGE
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    mapping(bytes32 pairID => mapping(uint256 strike => bytes32)) public strikeHashes;

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 LOGIC
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    function swap(SwapParams memory params, bytes calldata data) external {
        bytes32 pairID = getPairID(params.token0, params.token1);

        for (uint256 i = 0; i < params.strikes.length; i++) {
            Strike memory strike = params.strikes[i];

            bytes32 strikeHash = keccak256(abi.encode(strike));
            if (strikeHashes[pairID][strike.ratio] != strikeHash) revert InvalidStrikeHash();

            pairSwap(strike);

            strikeHashes[pairID][strike.ratio] = keccak256(abi.encode(strike));
        }

        ICallback(msg.sender).callback(data);
    }

    function addLiquidity(AddLiquidityParams memory params, bytes calldata data) external {
        bytes32 pairID = getPairID(params.token0, params.token1);

        bytes32 strikeHash = keccak256(abi.encode(params.strike));
        if (strikeHashes[pairID][params.strike.ratio] != strikeHash) revert InvalidStrikeHash();

        pairAddLiquidity(params.strike, params.amount);

        strikeHashes[pairID][params.strike.ratio] = keccak256(abi.encode(params.strike));

        ICallback(msg.sender).callback(data);
    }

    function removeLiquidity(RemoveLiquidityParams memory params, bytes calldata data) external {
        bytes32 pairID = getPairID(params.token0, params.token1);

        bytes32 strikeHash = keccak256(abi.encode(params.strike));
        if (strikeHashes[pairID][params.strike.ratio] != strikeHash) revert InvalidStrikeHash();

        pairRemoveLiquidity(params.strike, params.amount);

        strikeHashes[pairID][params.strike.ratio] = keccak256(abi.encode(params.strike));

        ICallback(msg.sender).callback(data);
    }
}
