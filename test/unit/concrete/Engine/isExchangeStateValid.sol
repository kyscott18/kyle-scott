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

    function test_isExchangeStateValid_Token1DriftPositive() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: int256(Q128 / 100)});
        ExchangeState memory state =
            ExchangeState({token: 1, amount: uint256(1e18 * 100) / 101 + 1, liquidity: 1e18, volume: 0, fee: 0});

        vm.resumeGasMetering();

        bool result = isExchangeStateValid(exchange, state);

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isExchangeStateValid_Token1DriftOverflow() external {
        vm.pauseGasMetering();

        Exchange memory exchange = Exchange({
            token0: address(0),
            token1: address(1),
            ratio: type(uint256).max,
            spread: 0,
            drift: int256(Q128 / 100)
        });
        ExchangeState memory state = ExchangeState({token: 1, amount: 1, liquidity: Q128 - 1, volume: 0, fee: 0});

        vm.resumeGasMetering();

        bool result = isExchangeStateValid(exchange, state);

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isExchangeStateValid_Token1DriftNegative() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: -int256(Q128 / 100)});
        ExchangeState memory state =
            ExchangeState({token: 1, amount: uint256(1e18 * 100) / 99 + 1, liquidity: 1e18, volume: 0, fee: 0});

        vm.resumeGasMetering();

        bool result = isExchangeStateValid(exchange, state);

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isExchangeStateValid_Token1DriftUnderflow() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: 0, spread: 0, drift: -int256(Q128 / 100)});
        ExchangeState memory state = ExchangeState({token: 1, amount: 0, liquidity: 0, volume: 0, fee: 0});

        vm.resumeGasMetering();

        bool result = isExchangeStateValid(exchange, state);

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isExchangeStateValid_SpreadTrue() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: Q128 / 100, drift: 0});
        ExchangeState memory state = ExchangeState({token: 1, amount: 1e18 + 2e16, liquidity: 1e18, volume: 0, fee: 0});

        vm.resumeGasMetering();

        bool result = isExchangeStateValid(exchange, state);

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isExchangeStateValid_SpreadFalse() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: Q128 / 100, drift: 0});
        ExchangeState memory state = ExchangeState({token: 1, amount: 1e18, liquidity: 1e18, volume: 0, fee: 0});

        vm.resumeGasMetering();

        bool result = isExchangeStateValid(exchange, state);

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }

    function test_isExchangeStateValid_FeeTrue() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: Q128 / 100, drift: 0});
        ExchangeState memory state =
            ExchangeState({token: 0, amount: 1e18 + 1e16, liquidity: 1e18, volume: 1e18, fee: 1e16});

        vm.resumeGasMetering();

        bool result = isExchangeStateValid(exchange, state);

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isExchangeStateValid_FeeFalse() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: Q128 / 100, drift: 0});
        ExchangeState memory state =
            ExchangeState({token: 0, amount: 1e18 + 1e16, liquidity: 1e18, volume: 1e18, fee: 1e16 - 1});
        vm.resumeGasMetering();

        bool result = isExchangeStateValid(exchange, state);

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }
}
