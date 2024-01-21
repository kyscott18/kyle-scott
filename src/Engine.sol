// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {
    getPairID,
    Strike,
    TokenSelector,
    swap as pairSwap,
    addLiquidity as pairAddLiquidity,
    removeLiquidity as pairRemoveLiquidity
} from "./Pair.sol";
import {Position} from "./Position.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/src/utils/SafeTransferLib.sol";

interface ICallback {
    /// @param data Extra data passed back to the callback from the caller
    function callback(bytes calldata data) external;
}

contract Engine is Position {
    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 ERRORS
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    error InsufficientInput();

    error InvalidStrikeHash();

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                               DATA TYPES
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    struct SwapParams {
        address token0;
        address token1;
        Strike[] strikes;
        address to;
    }

    struct AddLiquidityParams {
        address token0;
        address token1;
        Strike strike;
        uint256 amount;
        address to;
    }

    struct RemoveLiquidityParams {
        address token0;
        address token1;
        Strike strike;
        uint256 amount;
        address to;
    }

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                STORAGE
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    mapping(bytes32 pairID => mapping(uint256 strike => bytes32)) public strikeHashes;

    /*<//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>
                                 LOGIC
    <//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\>*/

    /// @dev First loop iteration sets "tokenIn" and "tokenOut"
    function swap(SwapParams memory params, bytes calldata data) external {
        bytes32 pairID = getPairID(params.token0, params.token1);

        address tokenIn;
        address tokenOut;

        uint256 amountIn;
        uint256 amountOut;

        for (uint256 i = 0; i < params.strikes.length; i++) {
            Strike memory strike = params.strikes[i];

            bytes32 strikeHash = keccak256(abi.encode(strike));
            if (strikeHashes[pairID][strike.ratio] != bytes32(0) && strikeHashes[pairID][strike.ratio] != strikeHash) {
                revert InvalidStrikeHash();
            }

            (uint256 amount0, uint256 amount1) = pairSwap(strike);
            strikeHashes[pairID][strike.ratio] = keccak256(abi.encode(strike));

            if (strike.token == TokenSelector.Token0) {
                if (tokenIn == address(0)) {
                    tokenIn = params.token0;
                    tokenOut = params.token1;
                }
                amountIn += amount0;
                amountOut -= amount1;
            } else {
                if (tokenIn == address(0)) {
                    tokenIn = params.token1;
                    tokenOut = params.token0;
                }
                amountIn += amount1;
                amountOut -= amount0;
            }
        }

        if (amountOut > 0) SafeTransferLib.safeTransfer(ERC20(tokenOut), params.to, amountOut);
        uint256 balanceBefore = ERC20(tokenIn).balanceOf(address(this));
        ICallback(msg.sender).callback(data);
        uint256 balanceAfter = ERC20(tokenIn).balanceOf(address(this));

        if (balanceBefore + amountIn > balanceAfter) revert InsufficientInput();
    }

    function addLiquidity(AddLiquidityParams memory params, bytes calldata data) external {
        bytes32 pairID = getPairID(params.token0, params.token1);

        bytes32 strikeHash = keccak256(abi.encode(params.strike));
        if (
            strikeHashes[pairID][params.strike.ratio] != bytes32(0)
                && strikeHashes[pairID][params.strike.ratio] != strikeHash
        ) revert InvalidStrikeHash();

        (uint256 amount0, uint256 amount1, uint256 liquidity) = pairAddLiquidity(params.strike, params.amount);
        strikeHashes[pairID][params.strike.ratio] = keccak256(abi.encode(params.strike));

        uint256 amount = params.strike.token == TokenSelector.Token0 ? amount0 : amount1;
        ERC20 token = ERC20(params.strike.token == TokenSelector.Token0 ? params.token0 : params.token1);
        bytes32 positionID = keccak256(abi.encode(ILRTADataID({pairID: pairID, strike: params.strike.ratio})));

        _mint(params.to, positionID, liquidity);
        uint256 balanceBefore = token.balanceOf(address(this));
        ICallback(msg.sender).callback(data);
        uint256 balanceAfter = token.balanceOf(address(this));

        if (balanceBefore + amount > balanceAfter) revert InsufficientInput();
    }

    function removeLiquidity(RemoveLiquidityParams memory params, bytes calldata data) external {
        bytes32 pairID = getPairID(params.token0, params.token1);

        bytes32 strikeHash = keccak256(abi.encode(params.strike));
        if (
            strikeHashes[pairID][params.strike.ratio] != bytes32(0)
                && strikeHashes[pairID][params.strike.ratio] != strikeHash
        ) revert InvalidStrikeHash();

        (uint256 amount0, uint256 amount1, uint256 liquidity) = pairRemoveLiquidity(params.strike, params.amount);
        strikeHashes[pairID][params.strike.ratio] = keccak256(abi.encode(params.strike));

        uint256 amount = params.strike.token == TokenSelector.Token0 ? amount0 : amount1;
        ERC20 token = ERC20(params.strike.token == TokenSelector.Token0 ? params.token0 : params.token1);
        bytes32 positionID = keccak256(abi.encode(ILRTADataID({pairID: pairID, strike: params.strike.ratio})));

        ILRTAData storage balanceBefore = _dataOf[address(this)][positionID];
        if (amount0 > 0) SafeTransferLib.safeTransfer(token, params.to, amount);
        ICallback(msg.sender).callback(data);
        ILRTAData storage balanceAfter = _dataOf[address(this)][positionID];

        if (balanceBefore.balance + liquidity > balanceAfter.balance) revert InsufficientInput();
    }
}
