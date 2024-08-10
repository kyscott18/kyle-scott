// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {Exchange, ExchangeState, Trade, isTradeValid} from "src/Engine.sol";
import {Q128} from "src/Math.sol";

contract isTradeValidTest is Test {
    function test_isTradeValid_Token0() external {
        vm.pauseGasMetering();

        Exchange memory exchange = Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 0, amount: 0, liquidity: 0, balance: 0, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0));

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_Token0FalseAmount() external {
        vm.pauseGasMetering();

        Exchange memory exchange = Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 0, amount: 0, liquidity: 0, balance: 0, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 0, amount: 1e18 - 1, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0));

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_Token0FalseBalance() external {
        vm.pauseGasMetering();

        Exchange memory exchange = Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 0, amount: 0, liquidity: 0, balance: 0, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, balance: 1e18 + 1, expiry: 0, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0));

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_Token1() external {
        vm.pauseGasMetering();

        Exchange memory exchange = Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 1, amount: 0, liquidity: 0, balance: 0, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 1, amount: 1e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0));

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_Token1FalseAmount() external {
        vm.pauseGasMetering();

        Exchange memory exchange = Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 1, amount: 0, liquidity: 0, balance: 0, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 1, amount: 1e18 - 1, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0));

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_Token1FalseBalance() external {
        vm.pauseGasMetering();

        Exchange memory exchange = Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 1, amount: 0, liquidity: 0, balance: 0, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 1, amount: 1e18, liquidity: 1e18, balance: 1e18 + 1, expiry: 0, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0));

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_Token1DriftPositive() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: int256(Q128)});
        ExchangeState memory stateBefore =
            ExchangeState({token: 1, amount: 0, liquidity: 0, balance: 0, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 1, amount: 0.5e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0));

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_Token1DriftOverflow() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: type(uint256).max, spread: 0, drift: int256(Q128)});
        ExchangeState memory stateBefore =
            ExchangeState({token: 1, amount: 0, liquidity: 0, balance: 0, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 1, amount: 1, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0));

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_Token1DriftNegative() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: 0, drift: -int256(Q128 / 2)});
        ExchangeState memory stateBefore =
            ExchangeState({token: 1, amount: 0, liquidity: 0, balance: 0, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 1, amount: 2e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0));

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_Token1DriftUnderflow() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: 0, spread: 0, drift: -int256(Q128 / 2)});
        ExchangeState memory stateBefore =
            ExchangeState({token: 1, amount: 0, liquidity: 0, balance: 0, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 1, amount: 0, liquidity: 0, balance: 0, expiry: 0, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0));

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_SwapTrue() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: Q128 / 2, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 1, amount: 1.5e18, liquidity: 1.5e18, balance: 1e18, expiry: 0, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0.5e18));

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_SwapFalseSpread() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: Q128 / 2, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter = ExchangeState({
            token: 1,
            amount: 1.5e18 - 1,
            liquidity: 1.5e18 - 1,
            balance: 1e18,
            expiry: 0,
            taker: address(0)
        });

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0.5e18 - 1));

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_SwapFalseFee() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: Q128 / 2, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter = ExchangeState({
            token: 1,
            amount: 1.5e18 - 1,
            liquidity: 1.5e18 - 1,
            balance: 1e18,
            expiry: 0,
            taker: address(0)
        });

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0.5e18));

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_ReserveOpenTrue() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: Q128 / 2, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter = ExchangeState({
            token: 0,
            amount: 1.5e18,
            liquidity: 1.5e18,
            balance: 1e18,
            expiry: block.number + 1,
            taker: address(this)
        });

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0.5e18));

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_ReserveOpenFalseExpiry() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: Q128 / 2, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});
        ExchangeState memory stateAfter = ExchangeState({
            token: 0,
            amount: 1.5e18,
            liquidity: 1.5e18,
            balance: 1e18,
            expiry: block.number,
            taker: address(this)
        });

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0.5e18));

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_TakerFalse() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: Q128 / 2, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(this)});
        ExchangeState memory stateAfter = ExchangeState({
            token: 0,
            amount: 1.5e18,
            liquidity: 1.5e18,
            balance: 1e18,
            expiry: block.number + 1,
            taker: address(msg.sender)
        });

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0.5e18));

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_ReserveCloseTrue() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: Q128 / 2, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(this)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 1, amount: 1e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0.5e18));

        vm.pauseGasMetering();

        assertEq(result, true);

        vm.resumeGasMetering();
    }

    function test_isTradeValid_ReserveCloseFalseExpiry() external {
        vm.pauseGasMetering();

        Exchange memory exchange =
            Exchange({token0: address(0), token1: address(1), ratio: Q128, spread: Q128 / 2, drift: 0});
        ExchangeState memory stateBefore =
            ExchangeState({token: 0, amount: 1e18, liquidity: 1e18, balance: 1e18, expiry: 0, taker: address(this)});
        ExchangeState memory stateAfter =
            ExchangeState({token: 1, amount: 1e18, liquidity: 1e18, balance: 1e18, expiry: 1, taker: address(0)});

        vm.resumeGasMetering();

        bool result = isTradeValid(Trade(exchange, stateBefore, stateAfter, 0.5e18));

        vm.pauseGasMetering();

        assertEq(result, false);

        vm.resumeGasMetering();
    }
}
