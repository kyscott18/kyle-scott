// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {Exchange, ExchangeState, isExchangeStateValid} from "src/Engine.sol";
import {Q128} from "src/Math.sol";

contract isExchangeStateValidTest is Test {
    function test_isExchangeStateValid_Token0() external {
        vm.pauseGasMetering();

        Exchange memory exchange = Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: 0});
        ExchangeState memory state = ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, volume: 0, fee: 0});

        vm.resumeGasMetering();

        bool result = isExchangeStateValid(exchange, state);

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isExchangeStateValid_Token0False() external {
        vm.pauseGasMetering();

        Exchange memory exchange = Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: 0});
        ExchangeState memory state = ExchangeState({token: 0, amount: 1e18 - 1, liquidity: 1e18, volume: 0, fee: 0});

        vm.resumeGasMetering();

        bool result = isExchangeStateValid(exchange, state);

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }

    function test_isExchangeStateValid_Token1() external {
        vm.pauseGasMetering();

        Exchange memory exchange = Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: 0});
        ExchangeState memory state = ExchangeState({token: 1, amount: 1e18, liquidity: 1e18, volume: 0, fee: 0});

        vm.resumeGasMetering();

        bool result = isExchangeStateValid(exchange, state);

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isExchangeStateValid_Token1False() external {
        vm.pauseGasMetering();

        Exchange memory exchange = Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: 0});
        ExchangeState memory state = ExchangeState({token: 1, amount: 1e18 - 1, liquidity: 1e18, volume: 0, fee: 0});

        vm.resumeGasMetering();

        bool result = isExchangeStateValid(exchange, state);

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }
}
