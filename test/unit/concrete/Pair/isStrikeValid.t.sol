// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {StrikeData, TokenSelector} from "src/Engine.sol";
import {Q128} from "src/Math.sol";
import {isStrikeValid} from "src/Pair.sol";

contract IsStrikeValidTest is Test {
    function test_IsStrikeValid_Token0() external {
        vm.pauseGasMetering();

        StrikeData memory strikeData =
            StrikeData({token: TokenSelector.Token0, amount: 1e18, liquidity: 1e18, volume: 0});

        vm.resumeGasMetering();

        bool result = isStrikeValid(0, 0, 0, strikeData);

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_IsStrikeValid_Token0False() external {
        vm.pauseGasMetering();

        StrikeData memory strikeData =
            StrikeData({token: TokenSelector.Token0, amount: 1e18 - 1, liquidity: 1e18, volume: 0});

        vm.resumeGasMetering();

        bool result = isStrikeValid(0, 0, 0, strikeData);

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }

    function test_IsStrikeValid_Token1() external {
        vm.pauseGasMetering();

        StrikeData memory strikeData =
            StrikeData({token: TokenSelector.Token1, amount: 1e18, liquidity: 1e18, volume: 0});

        vm.resumeGasMetering();

        bool result = isStrikeValid(Q128, 0, 0, strikeData);

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_IsStrikeValid_Token1False() external {
        vm.pauseGasMetering();

        StrikeData memory strikeData =
            StrikeData({token: TokenSelector.Token1, amount: 1e18 - 1, liquidity: 1e18, volume: 0});

        vm.resumeGasMetering();

        bool result = isStrikeValid(Q128, 0, 0, strikeData);

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }
}
